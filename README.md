# Here are the source codes for building modules in MiniOS.

Before building modules, make sure you have enough space in the changes.dat file or in RAM. You need to copy the contents of the minios-install folder to the root of the MiniOS. For files copied to **/usr/bin**, assign permissions **755**.

The required parameters for the build can be assigned in **/etc/minios/config**. Only the variables **PACKAGE_VARIANT**, **OUTPUT**, **COMP_TYPE** can be changed. **PACKAGE_VARIANT** points to the list of packages, if there is one in the module being built. **OUTPUT** specifies where to put the output of commands. This can be **/dev/null** for building without output, **/dev/output** for displaying to the screen, or output to a file. **COMP_TYPE** - compression type. MiniOS based on Debian 10 and 11 supports **xz**, **lz4**, **zstd**.

To build a module, for example, **06-virtualbox**, create the **modules** folder in the user folder (**/home/live**), place the **06-virtualbox** folder (**/home/live/modules/06-virtualbox**), you don't need to assign any file permissions. To start the build, go to the folder containing the **modules** folder (**/home/live**) and run the command to start the build:
```sh
sudo minios-install build_modules
```
The finished module file will lie in the current folder from which you ran the command (**/home/live**).
