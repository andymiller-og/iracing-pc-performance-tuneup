"""Generate the synthetic eval fixtures in evals/eval-files.

Every file here is invented: made-up rigs, made-up settings, frame times drawn from a simple model of a CPU-bound,
a GPU-bound or a memory-stalled frame. Nothing comes from a real user's PC. The CSVs carry only the PresentMon 2.x
columns that scripts/Analyze-PresentMon.ps1 reads. Re-run with `py evals/generate-fixtures.py`; the seed is fixed,
so the output is reproducible.
"""
import math
import os
import random

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'eval-files')
COLS = ['Application', 'ProcessID', 'PresentRuntime', 'SyncInterval', 'AllowsTearing', 'PresentMode', 'TimeInSeconds',
        'MsBetweenPresents', 'MsCPUBusy', 'MsCPUWait', 'MsGPUBusy', 'MsGPUWait', 'GPUPower', 'GPUFrequency',
        'GPUTemperature', 'GPUUtilization', 'GPUMemorySize', 'GPUMemorySizeUsed', 'CPUUtilization']


def capture(path, seconds, fps_at, mode, gpu, seed, cpu_util=(18, 30)):
    """fps_at(t) -> target fps at time t. mode: 'cpu' | 'gpu' | 'mem'. gpu: dict of sensor ranges."""
    rnd = random.Random(seed)
    t = 0.0
    sens = {'p': gpu['power'][0], 'f': gpu['mhz'][0], 'temp': gpu['temp'][0], 'u': gpu['util'][0],
            'v': gpu['vram'][0], 'c': cpu_util[0]}
    with open(path, 'w', newline='') as fh:
        fh.write(','.join(COLS) + '\n')
        while t < seconds:
            target = fps_at(t) * (1 + rnd.gauss(0, 0.035))
            ft = 1000.0 / max(target, 20)
            if rnd.random() < 0.0006:          # occasional hitch
                ft *= rnd.uniform(1.6, 2.4)
            if mode == 'cpu':
                cpu_wait = rnd.uniform(0.11, 0.2)
                cpu_busy = ft - cpu_wait
                gpu_busy = ft * rnd.uniform(0.60, 0.70)
                gpu_wait = ft - gpu_busy - rnd.uniform(0.0, 0.2)
            else:                              # GPU-bound with Reflex: CPU busy tracks GPU time
                gpu_busy = ft * rnd.uniform(0.985, 1.0)
                gpu_wait = max(0.0, ft - gpu_busy - 0.05) * rnd.random() * 0.3
                cpu_wait = rnd.uniform(0.11, 0.2)
                cpu_busy = ft - cpu_wait
            # sensors drift slowly towards a target inside their range
            for k, rng in (('p', gpu['power']), ('f', gpu['mhz']), ('temp', gpu['temp']), ('u', gpu['util']),
                           ('v', gpu['vram']), ('c', cpu_util)):
                goal = rnd.uniform(*rng)
                sens[k] += (goal - sens[k]) * 0.02
            row = ['iRacingSim64DX11.exe', '4242', 'DXGI', '0', '1', 'Hardware: Independent Flip', f'{t:.5f}',
                   f'{ft:.4f}', f'{cpu_busy:.4f}', f'{cpu_wait:.4f}', f'{gpu_busy:.4f}', f'{max(gpu_wait, 0):.4f}',
                   f"{sens['p']:.2f}", f"{sens['f']:.0f}", f"{sens['temp']:.0f}", f"{sens['u']:.0f}",
                   str(gpu['vram_total']), f"{sens['v'] * 1e9:.0f}", f"{sens['c']:.2f}"]
            fh.write(','.join(row) + '\n')
            t += ft / 1000.0


def ini(path, sections):
    with open(path, 'w', newline='') as fh:
        for name, items in sections:
            fh.write(f'[{name}]\n')
            for k, v, comment in items:
                fh.write(f'{k}={v}'.ljust(48) + f'\t; {comment}\n')
            fh.write('\n')


def graphics(over=None):
    base = [
        ('ShaderQuality', 2, '0=low, 1=med, 2=high, 3=max'),
        ('AntiAliasMethod', 3, 'The type of Anti Aliasing method used: 0=None, 1=MSAA, 2=FXAA, 3=SMAA'),
        ('MSAASamples', 2, 'The number of MSAA samples (if MSAA is in use): 2, 4 or 8'),
        ('Sharpening', 1, '0=off, 1=sharpening enabled'),
        ('SharpeningAmount', 125, 'sharpening strength (10=min, 125=default, 300=max)'),
        ('EnableHDR', 0, '0=off, 1=on'),
        ('ResolutionScaling', 0, '0=off, else percent'),
        ('SSAO', 0, '0=off, 1=on'), ('HeatHaze', 0, '0=off, 1=heat haze enabled'),
        ('DepthOfField', 0, '0=off, 1=depth of field blurs enabled'), ('Distortion', 0, '0=off, 1=on'),
        ('SSRLevel', 0, '0=off, 1=low res, 2=full res'),
        ('ShadowMapType', 0, '0=off, 1=on'), ('DynamicShadowMaps', 0, '0=off, 1=on'), ('ShadowDetail', 0, '0=low, 1=high'),
        ('DNSMEnable', 0, '0=off 1=dynamic night shadow maps'),
        ('SkyRefreshRate', 1, '0=low, 1=med, 2=high'), ('CarDetail', 1, '0=low, 1=med, 2=high'),
        ('PitObjectDetail', 0, '0=off, 1=low, 2=med, 3=high'), ('WeekendDetail', 0, 'event detail'),
        ('GrandstandDetail', 0, '0=low, 1=med, 2=high'), ('CrowdDetail', 0, '0=off, 1=low, 2=med, 3=high'),
        ('ObjectDetail', 1, 'object population'), ('FoliageDetail', 1, 'foliage density'),
        ('TwoPassTrees', 0, '0=off, 1=on'), ('LowQualityTrees', 1, '1=low quality trees'),
        ('ParticleDetail', 1, '0=low, 1=med, 2=high'), ('ParticlesFullRes', 0, '0=reduced resolution, 1=full resolution'),
        ('HeadlightLevel', 0, 'headlight detail'), ('SteeringWheel', 1, '0=off, 1=on'), ('DriverHands', 1, '0=no, 1=yes'),
        ('MaxCockpitMirrors', 0, 'max cockpit mirrors'), ('MirrorDetail', 0, '0=off, 1=higher detail'),
        ('VirtualMirrors', 1, '0=off, 1=on'), ('HeadlightsInMirrors', 0, '0=off, 1=on'),
        ('MaxCarsToDraw', 40, 'max cars to draw'), ('MaxCarsToDrawInMirrors', 12, 'max cars to draw in mirrors'),
        ('MaxPitObjsToDraw', 20, 'max pit objects'), ('MaxPitObjsToDrawInMirrors', 4, 'max pit objects in mirrors'),
        ('LODMinFPSTarget', 60, 'below this fps the sim lowers LOD'), ('LODPctMin', 100, 'LOD percent min'),
        ('LimitFrameRate', 1, '0=no limit, 1=limit'), ('DesiredFPSLimit', 140, 'frame rate limit'),
        ('NvReflexMode', 1, '0=off, 1=enabled, 2=enabled+boost'), ('MaxPreRenderedFrames', 1, 'max pre-rendered frames'),
        ('VerticalSync', 0, '0=off, 1=on'), ('CacheSwap3HighResCars', 0, '0=off, 1=on'),
        ('CarPaint2048x2048', 0, '0=off, 1=on'), ('VidMemToUseMB', 7800, 'video memory budget'),
    ]
    over = over or {}
    return [(k, over.get(k, v), c) for k, v, c in base]


def display(w, h):
    return [('windowedWidth', w, 'windowed mode width'), ('windowedHeight', h, 'windowed mode height'),
            ('fullScreen', 0, '0=windowed, 1=full screen'), ('border', 0, '0=no border, 1=border')]


def monitor(n, curved, width, screen, dist, radius, per_mon, smp):
    return [('NumMonitors', n, '1 or 3'), ('MonitorType', curved, '0=flat or 1=curved'),
            ('MonitorWidth', width, '(mm) total width of each monitor (screen + bezels)'),
            ('ScreenWidth', screen, '(mm) usable width of each screen (no bezels)'),
            ('ViewingDist', dist, '(mm) Distance from eyes to center of monitor'),
            ('RadiusOfCurvature', radius, '(mm) Radius of screen curvature (ignored if type is flat)'),
            ('RenderViewPerMonitor', per_mon, '0=one projection, 1=one projection per monitor'),
            ('EnableSMPSurround', smp, '0=off, 1=NVIDIA simultaneous multi-projection')]


def app_ini(path, fov, mirror_fov=125):
    ini(path, [('View', [('drivingCamFOV', f'{fov:.6f}', 'computed driving FOV'),
                         ('virtualMirrorFOV', f'{mirror_fov:.6f}', 'virtual mirror FOV')]),
               ('Graphics', [('serverTransmitMaxCars', 63, 'cars transmitted by the server')])])


def main():
    import shutil
    shutil.rmtree(OUT, ignore_errors=True)
    for d in ('eval0', 'eval1', 'eval3'):
        os.makedirs(os.path.join(OUT, d))

    # Eval 0: triple 27" 1440p 144 Hz flat, RTX 3080 10 GB, Ryzen 7 5800X; a 40-car replay; CPU-bound.
    over = {'AntiAliasMethod': 0, 'Sharpening': 0, 'MaxCarsToDraw': 20, 'MaxCarsToDrawInMirrors': 8,
            'DesiredFPSLimit': 200, 'VidMemToUseMB': 7800}
    ini(os.path.join(OUT, 'eval0', 'rendererDX11Monitor.ini'),
        [('Display', display(7680, 1440)), ('Graphics Options', graphics(over)), ('Replay Graphics', graphics(over)),
         ('MonitorSetup', monitor(3, 0, 560, 556, 61, 1000, 1, 0)),
         ('User Options', [('reduceFramerate_WhenFocusLost', 1, 'Set to 0 to hold full framerate when another program has keyboard focus')])])
    app_ini(os.path.join(OUT, 'eval0', 'app.ini'), 179.0)
    capture(os.path.join(OUT, 'eval0', 'replay-cpu-bound.csv'), 180,
            lambda t: 99 + 6 * math.sin(t / 23.0), 'cpu',
            {'power': (195, 225), 'mhz': (1890, 1950), 'temp': (62, 66), 'util': (62, 71),
             'vram': (7.0, 7.3), 'vram_total': 10737418240}, seed=11, cpu_util=(14, 22))

    # Eval 1: single 3440x1440 165 Hz ultrawide, RTX 4060 Ti 8 GB, i5-13600K; 35-car rain start; memory-stalled.
    over = {'AntiAliasMethod': 3, 'CarDetail': 2, 'ParticlesFullRes': 0, 'MaxCarsToDraw': 36,
            'DesiredFPSLimit': 160, 'VidMemToUseMB': 6200}
    ini(os.path.join(OUT, 'eval1', 'rendererDX11Monitor.ini'),
        [('Display', display(3440, 1440)), ('Graphics Options', graphics(over)), ('Replay Graphics', graphics(over)),
         ('MonitorSetup', monitor(1, 1, 820, 800, 700, 1500, 0, 0))])
    capture(os.path.join(OUT, 'eval1', 'rain-start.csv'), 120,
            lambda t: (52 if t < 40 else 60) + 3 * math.sin(t / 9.0), 'mem',
            {'power': (112, 124), 'mhz': (2520, 2610), 'temp': (66, 70), 'util': (97, 99),
             'vram': (7.88, 7.98), 'vram_total': 8589934592}, seed=22, cpu_util=(25, 35))

    # Eval 3: triple 1440p, RTX 4080 16 GB, Ryzen 7 7800X3D. "Before" is one lap; "after" is four laps and the user
    # says they switched to MSAA 4x and Max shaders. The ini was copied while the sim was still running and still
    # shows the old values. Both captures are generated from the same model: nothing actually changed.
    over = {'AntiAliasMethod': 3, 'ShaderQuality': 2, 'Sharpening': 1, 'DesiredFPSLimit': 160,
            'VidMemToUseMB': 12500, 'LODMinFPSTarget': 60}
    ini(os.path.join(OUT, 'eval3', 'rendererDX11Monitor.ini'),
        [('Display', display(7680, 1440)), ('Graphics Options', graphics(over)), ('Replay Graphics', graphics(over)),
         ('MonitorSetup', monitor(3, 1, 710, 697, 650, 1500, 1, 1))])
    race = lambda t: (84 if t < 110 else 104) + 4 * math.sin(t / 13.0)
    gpu = {'power': (300, 318), 'mhz': (2700, 2760), 'temp': (68, 72), 'util': (98, 99),
           'vram': (11.2, 11.5), 'vram_total': 17171480576}
    capture(os.path.join(OUT, 'eval3', 'before-1-lap.csv'), 150, race, 'gpu', gpu, seed=33)
    capture(os.path.join(OUT, 'eval3', 'after-4-laps.csv'), 540, race, 'gpu', gpu, seed=34)


if __name__ == '__main__':
    main()
