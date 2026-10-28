"""Rebuild the editor-editable Curve3D from a compact four-sector arcade layout.

Run from the project root with Python 3. Distances are metres. Tight circular
corners meet long jump runways; smooth hills reach 110 metres.
"""
import math
from pathlib import Path

# Four rotated sectors: a long jump runway followed by linked tunnel bends.
POINTS = []
for quarter in range(4):
    # Distinct switchback depths keep each sector's steering rhythm recognizable.
    bend_x = (710, 725, 705, 720)[quarter]
    for x, z in [(650, 500), (650, -200), (bend_x, -350), (650, -500)]:
        for _ in range(quarter):
            x, z = z, -x
        POINTS.append((x * 1.04, z * 1.04))
RADIUS = 70.0
HILL_COUNT = 4
HILL_HEIGHT = 110.0
MAX_SPAN = 16.0


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
    points = POINTS
    corners = []
    for i, center in enumerate(points):
        incoming = norm(sub(center, points[i-1]))
        outgoing = norm(sub(points[(i+1) % len(points)], center))
        angle = math.acos(max(-1, min(1, sum(a*b for a, b in zip(incoming, outgoing)))))
        radius = RADIUS
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
    # Arc-length tables keep the smooth hill profile independent of corner spacing.
    tables = []
    total = 0.0
    for span in spans:
        table = [0.0]
        for j in range(100):
            table.append(table[-1] + math.dist(bezier(span, j/100), bezier(span, (j+1)/100)))
        tables.append(table)
        total += table[-1]
    period = total / HILL_COUNT

    def hill(distance):
        # Continuous pitch avoids snapping the ship and camera at steep crests.
        phase = 2 * math.pi * (distance + 380.0) / period
        return (HILL_HEIGHT * (1 - math.cos(phase)) / 2,
                HILL_HEIGHT * math.pi / period * math.sin(phase))

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
        height, grade = hill(distance)
        # Matching slopes keep pitch continuous through each crest.
        values.extend([incoming[0], -grade * math.hypot(*incoming), incoming[1]])
        values.extend([outgoing[0], grade * math.hypot(*outgoing), outgoing[1]])
        values.extend([pos[0], height, pos[1]])
    nodes = segments
    serialized = ', '.join(f'{value:.5f}' for value in values)
    tilts = ', '.join('0' for _ in range(len(nodes)+1))
    Path('resources/city_circuit.tres').write_text(
        '[gd_resource type="Curve3D" format=3]\n[resource]\nbake_interval = 3.0\n'
        f'_data = {{\n"points": PackedVector3Array({serialized}),\n'
        f'"tilts": PackedFloat32Array({tilts})\n}}\npoint_count = {len(nodes)+1}\n')
    print(f'Horizontal length {total:.1f} m; {len(nodes)+1} points; hill period {period:.1f} m')


if __name__ == '__main__':
    generate()
