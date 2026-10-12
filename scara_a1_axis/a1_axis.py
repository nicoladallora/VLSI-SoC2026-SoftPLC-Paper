"""
a1_axis.py
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Optional
import math
import time
import threading

import lgpio


class AxisError(RuntimeError):
    pass


class SoftLimitError(AxisError):
    pass


def _precise_wait(dt: float) -> None:
    if dt <= 0:
        return
    if dt > 0.002:
        time.sleep(max(0.0, dt - 0.001))
    end = time.perf_counter() + dt
    while time.perf_counter() < end:
        pass


@dataclass(frozen=True)
class StepDirPins:
    step: int = 24
    dir: int = 5
    en: int = 6


@dataclass(frozen=True)
class EndstopConfig:
    pin: int = 23
    active_low: bool = True


@dataclass(frozen=True)
class Mechanics:
    motor_full_steps_per_rev: int = 200
    microsteps: int = 16
    motor_pulley_teeth: int = 20
    output_pulley_teeth: int = 110
    idler_teeth: Optional[int] = 80

    @property
    def drive_ratio(self) -> float:
        return self.output_pulley_teeth / float(self.motor_pulley_teeth)


@dataclass(frozen=True)
class MotionLimits:
    min_deg: float = -145.0
    max_deg: float = +145.0
    max_speed_deg_s: float = 120.0
    max_accel_deg_s2: float = 480.0


@dataclass(frozen=True)
class PulseTiming:
    step_high_us: int = 3
    min_step_period_us: int = 40


class A1Axis:
    """
    Gestore asse A1 open-loop.

    API di alto livello:
    - open()/close(): gestione risorsa gpiochip
    - enable()/disable(): abilita driver (EN active-low)
    - home(): esegue homing su finecorsa
    - move_to_deg(): comando di posizione in gradi
    - move_by_deg(): spostamento relativo
    - stop(): stop software (interrompe un movimento)
    """

    def __init__(
        self,
        pins: StepDirPins = StepDirPins(),
        mech: Mechanics = Mechanics(),
        limits: MotionLimits = MotionLimits(),
        timing: PulseTiming = PulseTiming(),
        home: Optional[EndstopConfig] = EndstopConfig(),
        enable_active_low: bool = True,
        invert_dir: bool = False,
        require_homed_for_moves: bool = True,
        gpiochip: int = 0,
        name: str = "A1",
    ) -> None:
        self.name = name
        self.pins = pins
        self.mech = mech
        self.limits = limits
        self.timing = timing
        self.home_cfg = home

        self.enable_active_low = enable_active_low
        self.invert_dir = invert_dir
        self.require_homed_for_moves = require_homed_for_moves
        self.gpiochip = gpiochip

        self._chip: Optional[int] = None
        self._enabled: bool = False
        self._homed: bool = False
        self._pos_steps: int = 0

        self._stop_evt = threading.Event()
        self._lock = threading.RLock()

    @property
    def steps_per_output_rev(self) -> float:
        return (
            self.mech.motor_full_steps_per_rev
            * self.mech.microsteps
            * self.mech.drive_ratio
        )

    def deg_to_steps(self, deg: float) -> int:
        return int(round((deg / 360.0) * self.steps_per_output_rev))

    def steps_to_deg(self, steps: int) -> float:
        return (steps / self.steps_per_output_rev) * 360.0

    def deg_s_to_steps_s(self, deg_s: float) -> float:
        return (deg_s / 360.0) * self.steps_per_output_rev

    def deg_s2_to_steps_s2(self, deg_s2: float) -> float:
        return (deg_s2 / 360.0) * self.steps_per_output_rev

    @property
    def position_deg(self) -> float:
        return self.steps_to_deg(self._pos_steps)

    def info(self) -> str:
        spr = self.steps_per_output_rev
        return (
            f"{self.name} | microsteps={self.mech.microsteps} | "
            f"pulleys motor={self.mech.motor_pulley_teeth}T, out={self.mech.output_pulley_teeth}T "
            f"(idler={self.mech.idler_teeth}T) | "
            f"drive_ratio={self.mech.drive_ratio:.4f} | steps/rev_out={spr:.1f} | "
            f"steps/deg={spr/360.0:.3f} | deg/step={360.0/spr:.5f}"
        )

    def open(self) -> None:
        with self._lock:
            if self._chip is not None:
                return

            self._chip = lgpio.gpiochip_open(self.gpiochip)

            lgpio.gpio_claim_output(self._chip, self.pins.step, 0)
            lgpio.gpio_claim_output(self._chip, self.pins.dir, 0)
            lgpio.gpio_claim_output(self._chip, self.pins.en, self._en_level(False))

            if self.home_cfg is not None:
                lgpio.gpio_claim_input(self._chip, self.home_cfg.pin)

    def close(self) -> None:
        with self._lock:
            if self._chip is None:
                return
            try:
                self.disable()
            finally:
                lgpio.gpiochip_close(self._chip)
                self._chip = None

    def __enter__(self) -> "A1Axis":
        self.open()
        return self

    def __exit__(self, exc_type, exc, tb) -> None:
        self.close()

    def _require_chip(self) -> int:
        if self._chip is None:
            raise AxisError(f"{self.name}: gpiochip non aperto (chiamare open())")
        return self._chip

    def _en_level(self, enable: bool) -> int:
        if self.enable_active_low:
            return 0 if enable else 1
        return 1 if enable else 0

    def _set_enable(self, enable: bool) -> None:
        chip = self._require_chip()
        lgpio.gpio_write(chip, self.pins.en, self._en_level(enable))

    def _set_dir(self, sign: int) -> None:
        chip = self._require_chip()
        level = 1 if sign > 0 else 0
        if self.invert_dir:
            level ^= 1
        lgpio.gpio_write(chip, self.pins.dir, level)

    def _pulse_step(self, period_s: float) -> None:
        chip = self._require_chip()
        high = self.timing.step_high_us / 1_000_000.0
        min_period = self.timing.min_step_period_us / 1_000_000.0
        period_s = max(period_s, min_period, high * 2)

        lgpio.gpio_write(chip, self.pins.step, 1)
        _precise_wait(high)
        lgpio.gpio_write(chip, self.pins.step, 0)
        _precise_wait(period_s - high)

    def _home_active(self) -> bool:
        if self.home_cfg is None:
            raise AxisError(f"{self.name}: finecorsa HOME non configurato")
        chip = self._require_chip()
        level = lgpio.gpio_read(chip, self.home_cfg.pin)
        return (level == 0) if self.home_cfg.active_low else (level == 1)

    def enable(self) -> None:
        with self._lock:
            self._stop_evt.clear()
            self._set_enable(True)
            self._enabled = True

    def disable(self) -> None:
        with self._lock:
            if self._chip is None:
                return
            self._set_enable(False)
            self._enabled = False

    def stop(self) -> None:
        self._stop_evt.set()

    def clear_stop(self) -> None:
        self._stop_evt.clear()

    def home(
        self,
        direction: int = -1,
        seek_speed_deg_s: float = 25.0,
        latch_speed_deg_s: float = 5.0,
        backoff_deg: float = 5.0,
        set_pos_deg: float = 0.0,
        safety_travel_deg: float = 350.0,
    ) -> None:
        with self._lock:
            if not self._enabled:
                raise AxisError(f"{self.name}: chiamare enable() prima di home()")
            if self.home_cfg is None:
                raise AxisError(f"{self.name}: home() richiesto ma HOME non configurato")

            self.clear_stop()
            direction = 1 if direction >= 0 else -1

            if self._home_active():
                self._move_steps(
                    -direction * self.deg_to_steps(backoff_deg),
                    seek_speed_deg_s,
                    self.limits.max_accel_deg_s2,
                    enforce_limits=False,
                )

            self._seek_home(direction, seek_speed_deg_s, safety_travel_deg)

            self._move_steps(
                -direction * self.deg_to_steps(backoff_deg),
                seek_speed_deg_s,
                self.limits.max_accel_deg_s2,
                enforce_limits=False,
            )

            self._seek_home(direction, latch_speed_deg_s, max(30.0, backoff_deg * 3))

            self._pos_steps = self.deg_to_steps(set_pos_deg)
            self._homed = True

    def move_to_deg(
        self,
        target_deg: float,
        speed_deg_s: Optional[float] = None,
        accel_deg_s2: Optional[float] = None,
        enforce_limits: bool = True,
    ) -> None:
        with self._lock:
            if not self._enabled:
                raise AxisError(f"{self.name}: chiamare enable() prima di muovere")

            if self.require_homed_for_moves and not self._homed:
                raise AxisError(f"{self.name}: necessario eseguire home() prima dei movimenti")

            if enforce_limits and (
                target_deg < self.limits.min_deg or target_deg > self.limits.max_deg
            ):
                raise SoftLimitError(
                    f"{self.name}: target {target_deg:.2f} deg fuori limiti "
                    f"[{self.limits.min_deg:.2f}, {self.limits.max_deg:.2f}]"
                )

            delta = self.deg_to_steps(target_deg) - self._pos_steps
            self._move_steps(delta, speed_deg_s, accel_deg_s2, enforce_limits=enforce_limits)

    def move_by_deg(
        self,
        delta_deg: float,
        speed_deg_s: Optional[float] = None,
        accel_deg_s2: Optional[float] = None,
        enforce_limits: bool = True,
    ) -> None:
        self.move_to_deg(
            self.position_deg + delta_deg, speed_deg_s, accel_deg_s2, enforce_limits
        )

    def _seek_home(self, direction: int, speed_deg_s: float, safety_travel_deg: float) -> None:
        self._set_dir(direction)
        v = self.deg_s_to_steps_s(max(1e-6, speed_deg_s))
        period = 1.0 / v

        max_steps = abs(self.deg_to_steps(safety_travel_deg))
        moved = 0

        while not self._home_active():
            if self._stop_evt.is_set():
                raise AxisError(f"{self.name}: stop durante homing")
            if moved >= max_steps:
                raise AxisError(f"{self.name}: homing fallito (finecorsa non trovato)")

            self._pulse_step(period)
            self._pos_steps += direction
            moved += 1

    def _move_steps(
        self,
        delta_steps: int,
        speed_deg_s: Optional[float],
        accel_deg_s2: Optional[float],
        enforce_limits: bool,
    ) -> None:
        if delta_steps == 0:
            return

        self.clear_stop()

        sign = 1 if delta_steps > 0 else -1
        n = abs(delta_steps)
        self._set_dir(sign)

        v_deg = min(
            float(speed_deg_s or self.limits.max_speed_deg_s), self.limits.max_speed_deg_s
        )
        a_deg = min(
            float(accel_deg_s2 or self.limits.max_accel_deg_s2),
            self.limits.max_accel_deg_s2,
        )

        v = max(1e-6, self.deg_s_to_steps_s(v_deg))
        a = max(0.0, self.deg_s2_to_steps_s2(a_deg))

        n_acc = int((v * v) / (2.0 * a)) if a > 0 else 0

        if 2 * n_acc > n:
            n_acc = n // 2

        for i in range(n):
            if self._stop_evt.is_set():
                raise AxisError(f"{self.name}: stop durante movimento")

            if a > 0 and i < n_acc:
                v_i = math.sqrt(2.0 * a * (i + 1))
            elif a > 0 and i >= (n - n_acc) and n_acc > 0:
                v_i = math.sqrt(2.0 * a * (n - i))
            else:
                v_i = v

            v_i = min(v_i, v)
            period = 1.0 / max(1e-6, v_i)

            self._pulse_step(period)
            self._pos_steps += sign

            if enforce_limits:
                self._check_limits()

    def _check_limits(self) -> None:
        deg = self.position_deg
        if deg < self.limits.min_deg or deg > self.limits.max_deg:
            self.stop()
            raise SoftLimitError(f"{self.name}: superato limite ({deg:.2f} deg)")


if __name__ == "__main__":
    with A1Axis() as a1:
        print(a1.info())

        a1.enable()
        a1.home(direction=-1, set_pos_deg=0.0)

        a1.move_to_deg(90.0)
        a1.move_to_deg(-90.0)
        a1.move_to_deg(0.0)

        a1.disable()
