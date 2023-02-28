# Roadrunner Singularity Container

The goal of this repo is to enable the production of a singularity based minimum dependency `tRoadRunner` application for development and testing across different NVIDIA GPUs and for easier shared development. At this juncture it is assumed that you have `singularity` installed on you machine of choice. If not please contact your sysadmin or refer to the ample documentation [available online](https://docs.sylabs.io/guides/3.11/user-guide/index.html)

## Building the container
In order to build the roadrunner container for development so you can make all your edits before shipping out for testing I prefer the `--sandbox` method. In order to build a `sandbox` which is essentially a linux container is a local folder, you can run the following.

```
singularity build --sandbox --fakeroot --fix-perms my_container_folder roadrunner.def
```
The `--fakeroot` flag allows you root access within the container which we need to install the dependencies for development. The `--fix-perms` will allow you for you to remove the directory structure without needing higher privileges (sudo/su). 

## Running the code from within the container
The application can be used as an app or via the commandline. In order to access the application via commandline you can launch a `shell` inside the container as follows. This allows you to edit code and build the application once again should you need it
```
singularity shell --writable --fakeroot roadrunner.
```

The `--fakeroot` is only needed if you want to add addtional packages you might need (such as an editor of choice). This will alter you prompt and should look like 
```
Singularity>
```

Within this shell you should be able to launch the `tRoadRunner` application with the command
```
Singularity> /casa_builds/roadrunner/build/casacpp/synthesis/tRoadRunner
```
This should result in a commandline interface to the `tRoadRunner` application

## Building for different GPUs

The code is hardware specific and contains optimizations for different NVIDIA compute architectures. This can be achieved for now by altering the `only_till_casacpp.sh` file which contains the flags for building [kokkos](https://github.com/kokkos/kokkos). It is set by default for `AMPERE86` as testing was carried out on an NVIDIA A4000 for other versions the following flag needs to be altered `-DKokkos_ARCH_AMPERE86=ON` to a suitable version before the production of the container.
