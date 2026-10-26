"""Rebuild the editor-editable Curve3D from a rounded city-block layout.

Run from the project root with Python 3. Distances are metres. Rounded corners
use circular Bezier approximations; short spans keep the hill profile smooth.
"""
import math
from pathlib import Path

POINTS = [(0, -400), (-250, -650), (-250, -1050), (-650, -1300),
          (-1050, -1300), (-1300, -1100), (-1700, -1300), (-2150, -1300),
          (-2400, -1050), (-2400, -650), (-2200, -400), (-2400, 0),
          (-2400, 400), (-2150, 650), (-2150, 1050), (-1750, 1300),
          (-1350, 1300), (-1100, 1100), (-700, 1300), (-250, 1300),
          (0, 1050), (0, 650), (-200, 400), (0, 0)]
RADIUS = 95.0
HILL_HEIGHT = 130.0
HILL_RUN = 1050.0
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
    corners = []
    for i, center in enumerate(POINTS):
        incoming = norm(sub(center, POINTS[i-1]))
        outgoing = norm(sub(POINTS[(i+1) % len(POINTS)], center))
        angle = math.acos(max(-1, min(1, sum(a*b for a, b in zip(incoming, outgoing)))))
        # Broader linked bends contrast with the technical 95 m corners.
        radius = 160.0 if i in (5, 6, 17, 18) else RADIUS
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
        length = math.hypot(*delta)
        direction = norm(delta)
        # Keep a short, readable starting grid before the first direction change.
        if i == 0:
            grid_end = add(previous, mul(direction, 140.0))
            grid_delta = sub(grid_end, previous)
            spans.append([previous, add(previous, mul(grid_delta, 1/3)),
                          add(previous, mul(grid_delta, 2/3)), grid_end])
            previous = grid_end
            delta = sub(corner[0], previous)
            length = math.hypot(*delta)
        if length > 170.0:
            # A linked S interrupts every long straight. Scaling the offset by
            # length squared keeps short chicanes from becoming sharp kinks.
            normal = (-direction[1], direction[0])
            middle = add(add(previous, mul(delta, 0.5)), mul(normal, length**2 / 6000))
            handle = mul(direction, length / 6)
            spans.append([previous, add(previous, handle), sub(middle, handle), middle])
            spans.append([middle, add(middle, handle), sub(corner[0], handle), corner[0]])
        else:
            spans.append([previous, add(previous, mul(delta, 1/3)),
                          add(previous, mul(delta, 2/3)), corner[0]])
        spans.append(corner)
    # Split each cubic exactly, using its endpoint derivatives as handles.
    nodes = []
    distance = 0.0
    counts = [math.ceil(sum(math.dist(bezier(span, j/100), bezier(span, (j+1)/100))
                            for j in range(100)) / MAX_SPAN) for span in spans]
    for index, span in enumerate(spans):
        count = counts[index]
        for j in range(count):
            t = j / count
            pos = bezier(span, t)
            tangent = mul(derivative(span, t), 1 / (3 * count))
            if nodes:
                distance += math.dist(nodes[-1][0], pos)
            # The incoming handle belongs to the previous span at joins.
            if j == 0:
                incoming = mul(derivative(spans[index-1], 1), -1 / (3 * counts[index-1]))
            else:
                incoming = mul(tangent, -1)
            nodes.append((pos, incoming, tangent, distance))
    total = distance + math.dist(nodes[-1][0], nodes[0][0])
    period = total / HILL_COUNT
    # Cubic easing gives level crests and valleys while keeping grades below 20%.
    rise = HILL_RUN
    flat = (period - 2 * rise) / 2

    def hill(s):
        phase = s % period
        if phase < flat:
            return 0.0, 0.0
        if phase < flat + rise:
            t = (phase - flat) / rise
            return HILL_HEIGHT * t*t*(3-2*t), HILL_HEIGHT * 6*t*(1-t) / rise
        if phase < 2*flat + rise:
            return HILL_HEIGHT, 0.0
        t = (phase - 2*flat - rise) / rise
        return HILL_HEIGHT * (1-t*t*(3-2*t)), -HILL_HEIGHT * 6*t*(1-t) / rise

    values = []
    for pos, incoming, outgoing, s in nodes + [nodes[0]]:
        height, slope = hill(s)
        for handle, sign in [(incoming, -1), (outgoing, 1)]:
            values.extend([handle[0], sign * slope * math.hypot(*handle), handle[1]])
        values.extend([pos[0], height, pos[1]])
    serialized = ', '.join(f'{value:.5f}' for value in values)
    tilts = ', '.join('0' for _ in range(len(nodes)+1))
    Path('resources/city_circuit.tres').write_text(
        '[gd_resource type="Curve3D" format=3]\n[resource]\nbake_interval = 3.0\n'
        f'_data = {{\n"points": PackedVector3Array({serialized}),\n'
        f'"tilts": PackedFloat32Array({tilts})\n}}\npoint_count = {len(nodes)+1}\n')
    print(f'Horizontal length {total:.1f} m; {len(nodes)+1} points; hill flats {flat:.1f} m')


if __name__ == '__main__':
    generate()
