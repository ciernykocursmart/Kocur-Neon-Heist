"""Tiny level-authoring kit. Levels are designed in tools/build_maps.py with
these helpers and written out as ASCII maps in scripts/data/maps/*.gd.
See scripts/world/level_grid.gd for the legend."""


class Map:
    def __init__(self, w, h, border=True):
        self.w, self.h = w, h
        self.g = [[' '] * w for _ in range(h)]
        if border:
            self.rect(0, 0, w - 1, 0, '#')
            self.rect(0, h - 1, w - 1, h - 1, '#')
            self.rect(0, 0, 0, h - 1, '#')
            self.rect(w - 1, 0, w - 1, h - 1, '#')

    def put(self, x, y, ch):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.g[y][x] = ch

    def rect(self, x0, y0, x1, y1, ch):
        for y in range(min(y0, y1), max(y0, y1) + 1):
            for x in range(min(x0, x1), max(x0, x1) + 1):
                self.put(x, y, ch)

    def clear(self, x0, y0, x1, y1):
        self.rect(x0, y0, x1, y1, ' ')

    def ground(self, x0, x1, top, ch='#', bottom=None):
        """Solid from row `top` down to the bottom border (or `bottom`)."""
        self.rect(x0, top, x1, self.h - 1 if bottom is None else bottom, ch)

    def ceil(self, x0, x1, bottom, ch='#'):
        self.rect(x0, 0, x1, bottom, ch)

    def row(self, x0, x1, y, ch):
        self.rect(x0, y, x1, y, ch)

    def col(self, x, y0, y1, ch):
        self.rect(x, y0, x, y1, ch)

    def text(self, x, y, s):
        for i, c in enumerate(s):
            if c != '_':
                self.put(x + i, y, c)

    def pit(self, x0, x1, top, hazard='^'):
        """Carve a pit through the ground starting at row `top`, hazard on the floor."""
        self.clear(x0, top, x1, self.h - 2)
        self.row(x0, x1, self.h - 2, hazard)

    def dump(self):
        return '\n'.join(''.join(r).rstrip() for r in self.g)
