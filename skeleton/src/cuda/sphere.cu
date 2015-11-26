#define KINEMATIC
#define GRAVITY

#include <cstdlib>
#include <cuda_runtime.h>
#include <iostream>
#include <ctime>
#include "helper_math.h"	// overload operators for floatN
#include "helper_cuda.h"

#include "sphere.h"
#include "collision.h"

namespace CUDA {

__global__ void resetSpheresGrid(Sphere* spheres, int numberOfSpheres, int x, int z, float cornerX, float cornerY, float cornerZ, float distance)
{
    int tid = blockDim.x * blockIdx.x + threadIdx.x;
    if (tid < numberOfSpheres)
    {
        int layerSize = x * z;
        int yPos = tid / layerSize;
        int normId = tid - yPos * layerSize;

        int xPos = normId % x;
        int zPos = (normId - xPos) / x;

        spheres[tid].position.x = xPos * distance + cornerX;
        spheres[tid].position.y = yPos * distance + cornerY;
        spheres[tid].position.z = zPos * distance + cornerZ;
    }
}

__global__ void setImpulse(Sphere* spheres, int numberOfSpheres)
{
    int tid = blockDim.x * blockIdx.x + threadIdx.x;
    if (tid < numberOfSpheres)
    {
        spheres[tid].impulse = make_float3(1, 1, 1);
    }
}

__global__ void integrateSpheres(Sphere* spheres, int numberOfSpheres, float dt)
{
    int tid = blockDim.x * blockIdx.x + threadIdx.x;
    if (tid < numberOfSpheres)
    {
        Sphere& s = spheres[tid];

#ifdef GRAVITY
        s.impulse  += dt * make_float3(0, -1, 0); // gravity, breaks everything......
#endif
        s.position += dt * s.impulse;

        // DEBUG
        s.color = make_float4(s.impulse) / 5 + make_float4(1, 1, 1, 0);
    }

}

__global__ void collideSpheres(Sphere* spheres, Plane* planes, int numberOfSpheres, int numberOfPlanes, float dt)
{
    int tid = blockDim.x * blockIdx.x + threadIdx.x;
    if (tid < numberOfSpheres)
    {
        Sphere& updated = spheres[tid];
        Sphere prev     = updated;
        prev.position  -= dt * prev.impulse; // original position

        IntersectionData firstIntersection = make_intersectiondata();

        // TEST PLANES
        for (int p = 0; p < numberOfPlanes; ++p)
        {
            Plane& plane = planes[p];

            IntersectionData currentIntersection = collideSpherePlane(&prev, &plane, dt); // assumption: plane not moving
            if (currentIntersection.intersects)
            {
                if (!firstIntersection.intersects || currentIntersection.colTime < firstIntersection.colTime)
                {
                    firstIntersection = currentIntersection;
                }
            }
        }

        // TEST SPHERES
        for (int s = 0; s < numberOfSpheres; ++s)
        {
            if (s == tid) continue; // self

            Sphere& other_updated = spheres[s];
            Sphere other_prev     = other_updated;
            other_prev.position  -= dt * other_prev.impulse; // other original position

            IntersectionData currentIntersection = collideSphereSphere(&prev, &other_prev, dt);
            if (currentIntersection.intersects)
            {
                if (!firstIntersection.intersects || currentIntersection.colTime < firstIntersection.colTime)
                {
                    firstIntersection = currentIntersection;
                }
            }
        }



        // RESOLVE COLLISION
        if (firstIntersection.intersects)
        {
#ifdef KINEMATIC
            resolveCollisionKinematically(&updated, &firstIntersection);
#else
            resolveCollisionDynamically(&updated, &firstIntersection);
#endif

        }
        else
        {
            updated.newPos     = updated.position;
            updated.newImpulse = updated.impulse;
        }
    }
}

__global__ void updateSpheres(Sphere* spheres, int numberOfSpheres)
{
    int tid = blockDim.x * blockIdx.x + threadIdx.x;
    if (tid < numberOfSpheres)
    {
        Sphere& sphere = spheres[tid];

        sphere.position = sphere.newPos;
        sphere.impulse  = sphere.newImpulse;
    }
}

void resetSpheres(Sphere* spheres, int numberOfSpheres, int x, int z, float cornerX, float cornerY, float cornerZ, float distance)
{
    int threadsPerBlock = 128;
    int blocks = numberOfSpheres / threadsPerBlock + 1;
    resetSpheresGrid<<<blocks, threadsPerBlock>>>(spheres, numberOfSpheres, x, z, cornerX, cornerY, cornerZ, distance);
}

void updateAllSpheres(Sphere* spheres, Plane* planes, int numberOfSpheres, int numberOfPlanes, float dt)
{
    int threadsPerBlock = 128;
    int blocks = numberOfSpheres / threadsPerBlock + 1;
    integrateSpheres<<<blocks, threadsPerBlock>>>(spheres, numberOfSpheres, dt); // this way all threads are up to date
    collideSpheres<<<blocks, threadsPerBlock>>>(spheres, planes, numberOfSpheres, numberOfPlanes, dt);
    updateSpheres<<<blocks, threadsPerBlock>>>(spheres, numberOfSpheres);
}


}
