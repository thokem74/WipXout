"""Rebuild the editor-editable Curve3D from a rounded city-block layout.

Run from the project root with Python 3. Distances are metres. Circular corners
meet true straights directly; linear ten-percent grades meet level road directly.
"""
import bisect
import math
from pathlib import Path

POINTS = [(0, -400), (-250, -650), (-250, -1050), (-650, -1300),
          (-1050, -1300), (-1300, -1100), (-1700, -1300), (-2150, -1300),
          (-2400, -1050), (-2400, -650), (-2200, -400), (-2400, 0),
          (-2400, 400), (-2150, 650), (-2150, 1050), (-1750, 1300),
          (-1350, 1300), (-1100, 1100), (-700, 1300), (-250, 1300),
          (0, 1050), (0, 650), (-200, 400), (0, 0)]
RADIUS = 95.0
GRADIENT = 0.10
HILL_COUNT = 4
MAX_SPAN = 35.0


def add(a, b):
    return tuple(x + y for x, y in zip(a, b))


def mul(a, scale):
    return tuple(x * scale for x in a)


def sub(a, b):
    return add(a, mul(b, -1))


def norm(a):
    return mul(a, 1 / math.hypot(*a))


def bezier(p, t):
    return tuple(sum(p[k][axis] * weight for k, weight in enumerate(
        [(1-t)**3, 3*(1-t)**2*t, 3*(1-t)*t*t, t**3])) for axis in range(2))


def derivative(p, t):
    return add(add(mul(sub(p[1], p[0]), 3*(1-t)**2),
                   mul(sub(p[2], p[1]), 6*(1-t)*t)),
               mul(sub(p[3], p[2]), 3*t*t))


def generate():
    # Divide long city blocks with explicit corners, rather than eased S-curves.
    # Every connecting span is truly straight; curvature changes at the arc lip.
    points = []
    broad_corners = {POINTS[i] for i in (3, 4, 5, 6, 15, 16, 17, 18)}
    for i, center in enumerate(POINTS):
        previous = POINTS[i-1]
        delta = sub(center, previous)
        if math.hypot(*delta) > 300:
            normal = norm((-delta[1], delta[0]))
            midpoint = add(add(previous, mul(delta, 0.5)), mul(normal, 50 if i % 2 else -50))
            points.append(midpoint)
            if center in broad_corners or previous in broad_corners:
                broad_corners.add(midpoint)
        points.append(center)
    corners = []
    for i, center in enumerate(points):
        incoming = norm(sub(center, points[i-1]))
        outgoing = norm(sub(points[(i+1) % len(points)], center))
        angle = math.acos(max(-1, min(1, sum(a*b for a, b in zip(incoming, outgoing)))))
        radius = 160.0 if center in broad_corners else RADIUS
        setback = radius * math.tan(angle / 2)
        handle = 4 / 3 * radius * math.tan(angle / 4)
        entry = sub(center, mul(incoming, setback))
        exit_point = add(center, mul(outgoing, setback))
        corners.append([entry, add(entry, mul(incoming, handle)),
                        sub(exit_point, mul(outgoing, handle)), exit_point])
    spans = []
    for i, corner in enumerate(corners):
        previous = corners[i-1][-1]
        delta = sub(corner[0], previous)
        direction = norm(sub(points[i], points[i-1]))
        if sum(a*b for a,b in zip(delta, direction)) <= 0:
            raise ValueError("Corner radii overlap: shorten the adjacent handles")
        spans.append([previous, add(previous, mul(delta, 1/3)),
                      add(previous, mul(delta, 2/3)), corner[0]])
        spans.append(corner)
    # Arc-length tables locate every grade break exactly inside a planar cubic.
    tables = []
    total = 0.0
    for span in spans:
        table = [0.0]
        for j in range(100):
            table.append(table[-1] + math.dist(bezier(span, j/100), bezier(span, (j+1)/100)))
        tables.append(table)
        total += table[-1]
    period = total / HILL_COUNT
    # Account for the extra 3D length of slopes: exactly one third of the
    # travelled course is graded, and two thirds is level.
    sloped_fraction = 1.0 / (1.0 + 2.0 * math.sqrt(1.0 + GRADIENT**2))
    rise = period * sloped_fraction / 2.0
    hill_height = rise * GRADIENT
    flat = (period - 2 * rise) / 2
    if flat < 110:
        raise ValueError("Keep enough level road for both jump approaches")
    phase_offset = flat * 0.5  # Put the lap seam inside level road.

    def hill(distance):
        phase = (distance + phase_offset) % period
        if phase < flat:
            return 0.0, 0.0
        if phase < flat + rise:
            return hill_height * (phase - flat) / rise, hill_height / rise
        if phase < 2 * flat + rise:
            return hill_height, 0.0
        return hill_height * (1 - (phase - 2 * flat - rise) / rise), -hill_height / rise

    breaks = []
    for lap in range(HILL_COUNT + 1):
        for phase in (0.0, flat, flat + rise, 2 * flat + rise):
            distance = lap * period + phase - phase_offset
            if 0 < distance < total:
                breaks.append(distance)
    breaks.sort()
    segments = []
    span_start = 0.0
    for span, table in zip(spans, tables):
        count = math.ceil(table[-1] / MAX_SPAN)
        cuts = {}
        for j in range(count + 1):
            t = j / count
            sample = min(99, int(t * 100))
            fraction = t * 100 - sample
            cuts[t] = span_start + table[sample] + fraction * (table[sample+1] - table[sample])
        for distance in breaks:
            local = distance - span_start
            if 0 < local < table[-1]:
                index = bisect.bisect_left(table, local)
                fraction = (local - table[index-1]) / (table[index] - table[index-1])
                cuts[(index - 1 + fraction) / 100] = distance
        times = sorted(cuts)
        for first, second in zip(times, times[1:]):
            segments.append((bezier(span, first), mul(derivative(span, first), (second-first)/3),
                             mul(derivative(span, second), -(second-first)/3),
                             cuts[first]))
        span_start += table[-1]
    values = []
    for index in range(len(segments) + 1):
        pos, outgoing, _, distance = segments[index % len(segments)]
        incoming = segments[(index-1) % len(segments)][2]
        height, _ = hill(distance)
        # Distinct incoming/outgoing grades produce deliberate hard pitch changes.
        _, before = hill(distance - 0.0001)
        _, after = hill(distance + 0.0001)
        values.extend([incoming[0], -before * math.hypot(*incoming), incoming[1]])
        values.extend([outgoing[0], after * math.hypot(*outgoing), outgoing[1]])
        values.extend([pos[0], height, pos[1]])
    nodes = segments
    serialized = ', '.join(f'{value:.5f}' for value in values)
    tilts = ', '.join('0' for _ in range(len(nodes)+1))
    Path('resources/city_circuit.tres').write_text(
        '[gd_resource type="Curve3D" format=3]\n[resource]\nbake_interval = 3.0\n'
        f'_data = {{\n"points": PackedVector3Array({serialized}),\n'
        f'"tilts": PackedFloat32Array({tilts})\n}}\npoint_count = {len(nodes)+1}\n')
    print(f'Horizontal length {total:.1f} m; {len(nodes)+1} points; hill flats {flat:.1f} m')


if __name__ == '__main__':
    generate()
