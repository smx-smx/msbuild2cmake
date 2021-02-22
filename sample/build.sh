#!/bin/sh
dotnet msbuild /p:Configuration=Debug /p:Platform=AnyCPU ./BuildTargets/BuildTargets.csproj -t:sample_cmake_target