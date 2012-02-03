# -*- Mode: python; tab-width: 4; indent-tabs-mode:nil; -*-
# vim: tabstop=4 expandtab shiftwidth=4 softtabstop=4
#
# MDAnalysis --- http://mdanalysis.googlecode.com
# Copyright (c) 2006-2011 Naveen Michaud-Agrawal,
#               Elizabeth J. Denning, Oliver Beckstein,
#               and contributors (see website for details)
# Released under the GNU Public Licence, v2 or any higher version
#
# Please cite your use of MDAnalysis in published work:
#
#     N. Michaud-Agrawal, E. J. Denning, T. B. Woolf, and
#     O. Beckstein. MDAnalysis: A Toolkit for the Analysis of
#     Molecular Dynamics Simulations. J. Comput. Chem. 32 (2011), 2319--2327,
#     doi:10.1002/jcc.21787
#

cimport c_numpy
c_numpy.import_array()

ctypedef int size_t

import numpy

cdef extern from "tess.h":
    ctypedef long int integer
    ctypedef double real
    int tess_(integer *mrowp, integer *mp, integer *np, real *p, integer *mrows, integer *ncols, integer *ms, integer *ns, integer *nsim, integer *nadj, real *work, integer *llfact, integer *iwork, integer *ierr)

cdef extern from "math.h":
    float sqrtf(float x)
    double sqrt(double x)

cdef extern from "stdio.h":
    int printf(char *format, ...)

def circumcircles(c_numpy.ndarray vertices, c_numpy.ndarray triangles):
    cdef integer* tri
    cdef real *v, *c, *r
    cdef real *v0, *v1, *v2
    cdef real xd0, yd0, xa0, ya0
    cdef double a2, b2, numerator, denominator
    cdef real centerx, centery, radius
    cdef c_numpy.ndarray centers, rad
    cdef int i, numtri, dimtri

    numtri = triangles.dimensions[0]
    dimtri = triangles.dimensions[1]
    v = <real*> vertices.data
    tri = <integer*> triangles.data
    centers = numpy.zeros((numtri, 2), numpy.float64)
    rad = numpy.zeros((numtri), numpy.float64)
    c = <real*> centers.data
    r = <real*> rad.data

    #calculate circumcenter
    for i from 0 <= i < numtri:
        v0 = &v[tri[i*dimtri+0]*2]
        v1 = &v[tri[i*dimtri+1]*2]
        v2 = &v[tri[i*dimtri+2]*2]
        xd0 = v1[0]-v0[0]
        yd0 = v1[1]-v0[1]
        xa0 = v2[0]-v0[0]
        ya0 = v2[1]-v0[1]

        a2 = xd0*xd0+yd0*yd0
        b2 = xa0*xa0+ya0*ya0
        numerator=(xd0*ya0 - xa0*yd0)
        if not (numerator==0): denominator = 0.5/numerator
        else: raise Exception("Some points are collinear!")

        centerx = v0[0] - (yd0 *b2 - ya0 *a2) * denominator
        centery = v0[1] + (xd0 * b2 - xa0 * a2) * denominator
        c[i*2+0] = centerx
        c[i*2+1] = centery
        r[i] = sqrt((centerx-v0[0])*(centerx-v0[0])+(centery-v0[1])*(centery-v0[1]))

    return centers, rad

def triangulate(c_numpy.ndarray points):
    cdef integer mrowp, mp, np
    cdef integer mrows, ncols
    cdef integer ms, ns, ierr, liw, llfact
    cdef c_numpy.ndarray iwork, work, nsim, nadj

    if points.nd != 2: raise Exception("delaunay: incorrect number of dimensions")
    if points.dtype != numpy.dtype(numpy.float64): raise Exception("delaunay: array must be of type double")
    np = points.dimensions[0]
    mrowp = mp = points.dimensions[1]
    ierr = 0
    ms = mp+1
    mrows = mrowp + 1
    ncols = 12*np
    llfact = 20
    liw = 7*llfact*np
    iwork = numpy.zeros((liw), numpy.int)
    work = numpy.zeros((5*mrowp+mrowp*mrowp), numpy.float64)
    nsim = numpy.zeros((ncols,mrows), numpy.int)
    nadj = numpy.zeros((ncols,mrows), numpy.int)
    tess_(&mrowp, &mp, &np, <real*>points.data, &mrows, &ncols, &ms, &ns, <integer*>nsim.data, <integer*>nadj.data, <real*>work.data, &llfact, <integer*>iwork.data, &ierr)
    if (ierr != 0):
        #print nsim
        raise Exception("Error in tesselation: error %d, ns %d"%(ierr, ns))
    return nsim[:ns], nadj[:ns]