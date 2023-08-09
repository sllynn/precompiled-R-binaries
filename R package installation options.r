# Databricks notebook source
# MAGIC %md # Issue description

# COMMAND ----------

# MAGIC %md ## R packages and native code dependencies
# MAGIC - Many R packages which allow users to execute computationally intensive tasks (e.g. geospatial data processing, simulation or probabilistic modelling) have dependencies on C, C++, and Fortran code which is linked and called at run time.
# MAGIC - In order for this to work, the linked code needs to be compiled and available to the R interpreter. Exactly what this compiled code looks like will depend on the OS, platform architecture and compilation toolchain of the machine on which the R interpreter is running.
# MAGIC - Most R package maintainers publish their source code (including any "native" elements) to CRAN, the centralised repository for R packages. CRAN tests that the code will compile and run on a number of different host ['flavours'](https://cran.r-project.org/web/checks/check_flavors.html) before allowing submission and updating the repository index.

# COMMAND ----------

# MAGIC %md ## How R packages are served from CRAN
# MAGIC - For each package in the repository index, CRAN hosts both the source code and a selection of pre-compiled binaries for common OS, arch and R version combinations.
# MAGIC - When you ask to install a package from the R interpreter (or from within RStudio), R checks to see if a pre-compiled binary is available for your platform. If you're working in Windows or MacOS, this generally _will_ be the case and you can quickly install packages without the need to compile them from source in your local environment.
# MAGIC - In the case of Linux systems, the CRAN maintainers have determined that there are just too many variants of OS and architecture to make serving pre-compiled binaries practical. Instead, CRAN provides only the source code and compilation / installation recipe for Linux users. When you request a new package, your R interpreter must kick-off and oversee this process.
# MAGIC - This is why, when installing packages within the Databricks driver / worker environments (which currently run on Ubuntu linux 22.04), the installation process often takes more time to complete.

# COMMAND ----------

# MAGIC %md ## Databricks clusters
# MAGIC - Databricks clusters are "persist nothing" compute environments where user libraries do not persist between restarts.
# MAGIC - Each package pinned to the cluster must therefore be reinstalled when the cluster starts up.
# MAGIC - Pinning lots of R packages to the cluster in the Clusters UI can result in very long start-up times (especially if these are packages with heavy native code dependencies) and will prevent any users executing code on the cluster until the installation process(es) are completed.

# COMMAND ----------

# MAGIC %md ## Notebook scoped libraries
# MAGIC Libraries in Databricks _do not_ need to be cluster-scoped.
# MAGIC - They can be installed from within the notebook code, helping ameliorate issues around version clash, slow start-up time and issues around reproducibility. Consider whether this is a better option for your team.
# MAGIC - The trade off is that the installation is only deferred to the point in time that a given user needs to use a particular package. Packages will still need to be reinstalled when the notebook is detached from the cluster, either through a manual detach / reattach operation, or by the cluster being terminated through inactivity.

# COMMAND ----------

# MAGIC %md ## RStudio
# MAGIC Multiple options exist for working with RStudio on Databricks.
# MAGIC - You can connect your RStudio client to a Databricks Cluster or SQL Warehouse using the J/ODBC connectors to retrieve data and perform your analysis locally. In this case, you shouldn't need to install R packages on the cluster at all.
# MAGIC - You can also choose to run RStudio server on the cluster driver and access the interface through the Clusters UI. In this scenario, you still face the obstacle of needing to install packages onto the cluster.

# COMMAND ----------

# MAGIC %md
# MAGIC # Alternative options for R package installation
# MAGIC ### (without the need to compile from source)

# COMMAND ----------

# MAGIC %md ## Benchmark long-running installation task

# COMMAND ----------

install.packages("arrow")

# COMMAND ----------

# MAGIC %md
# MAGIC ## Option 1. Use pre-built binaries from the `c2d4u` Personal Package Archive
# MAGIC Method as described on the [R Project website](https://cran.r-project.org/bin/linux/ubuntu/).

# COMMAND ----------

# MAGIC %md
# MAGIC ### Step 1: Add the `c2d4u` PPA and refresh the index

# COMMAND ----------

# MAGIC %sh add-apt-repository --yes "ppa:c2d4u.team/c2d4u4.0+" \
# MAGIC && apt-get update

# COMMAND ----------

# MAGIC %md
# MAGIC ### Step 2: Search for the package you need
# MAGIC #### (names usually prepended with r-cran-*)

# COMMAND ----------

# MAGIC %sh apt search arrow

# COMMAND ----------

# MAGIC %md
# MAGIC ### Step 3: Install the package using the Ubuntu package manager

# COMMAND ----------

# MAGIC %sh apt-get install -y r-cran-arrow

# COMMAND ----------

# MAGIC %md < 1min vs. 6 mins

# COMMAND ----------

# MAGIC %md
# MAGIC ### Step 4: Test

# COMMAND ----------

library(arrow)
tbl <- tibble::tibble(
  int = 1:10,
  dbl = as.numeric(1:10),
  lgl = sample(c(TRUE, FALSE, NA), 10, replace = TRUE),
  chr = letters[1:10],
  fct = factor(letters[1:10])
)
batch <- record_batch(tbl)
display(as.data.frame(batch))

# COMMAND ----------

# MAGIC %md #### Notes
# MAGIC This approach will make the library available on the driver node of the cluster but _not_ the workers. In order to install the package to all of the cluster nodes, wrap the above code in an init script and attach it to the cluster using the options in the Clusters UI.

# COMMAND ----------

# MAGIC %md ## Option 2: Use pre-built binaries from `posit`

# COMMAND ----------

# MAGIC %md [The Posit Public Package Manager](https://posit.co/products/cloud/public-package-manager/) is a public repository run by the Posit team (the company formally known as RStudio). They helpfully compile binaries for many Linux distributions, including Ubuntu Jammy which Databricks uses (as of the time of writing).

# COMMAND ----------

# MAGIC %md ### Step 1: Upfront configuration
# MAGIC See step 3 for how this can be configured at cluster start.

# COMMAND ----------

options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))
options(download.file.extra = sprintf("--header \"User-Agent: R (%s)\"", paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))
options(repos = c("CRAN" = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"))

# COMMAND ----------

# MAGIC %md ### Step 2: Install packages

# COMMAND ----------

install.packages("arrow")

# COMMAND ----------

# MAGIC %md `* installing *binary* package ‘arrow’ ...` shows us we are installing from the pre-compiled package version.

# COMMAND ----------

# MAGIC %md
# MAGIC ### Step 3: Configuring as the default using cluster environment variables and `Rprofile.site`

# COMMAND ----------

# MAGIC %md #### 3.1 Set the cluster environment variables
# MAGIC
# MAGIC In the clusters UI, add a new environment variable `DATABRICKS_DEFAULT_R_REPOS` and set it equal to `"https://packagemanager.posit.co/cran/__linux__/jammy/latest"`.

# COMMAND ----------

# MAGIC %md #### 3.2 Configure Rprofile.site
# MAGIC
# MAGIC Copy default Rprofile.site to your workspace.

# COMMAND ----------

# MAGIC %sh cp /usr/lib/R/etc/Rprofile.site /Workspace/Users/<your_user>/<path_to_folder>/

# COMMAND ----------

# MAGIC %md
# MAGIC Add these lines to the end of the Rprofile.site file now available in your workspace folder:
# MAGIC ```
# MAGIC options(HTTPUserAgent = sprintf("R/%s R (%s)", getRversion(), paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))
# MAGIC options(download.file.extra = sprintf("--header \"User-Agent: R (%s)\"", paste(getRversion(), R.version["platform"], R.version["arch"], R.version["os"])))
# MAGIC ```

# COMMAND ----------

# MAGIC %md
# MAGIC Copy the file back to dbfs (as the workspace file system is not accessible during cluster start).

# COMMAND ----------

# MAGIC %sh cp /Workspace/Users/<your_user>/<path_to_folder>/Rprofile.site /dbfs/Users/<your_user>/<path_to_folder>/Rprofile.site

# COMMAND ----------

# MAGIC %md #### 3.3 Create an init script to copy Rprofile.site into the cluster file system at startup
# MAGIC
# MAGIC Create the init script and store it in the workspace file system.

# COMMAND ----------

# MAGIC %python
# MAGIC init_script = """cp /dbfs/Users/<your_user>/<path_to_folder>/Rprofile.site /usr/lib/R/etc/Rprofile.site"""
# MAGIC dbutils.fs.put("file:/Workspace/Users/<your_user>/<path_to_folder>/init_script.sh", init_script, True)

# COMMAND ----------

# MAGIC %md
# MAGIC Attach this init script to your cluster and restart.
# MAGIC
# MAGIC Now you can install packages without configuring the environment variables in each notebook session.

# COMMAND ----------

install.packages("arrow")

# COMMAND ----------

# MAGIC %md ## Option 3: Cache your binaries on DBFS
# MAGIC Simplified process using `renv`, negates the need to adjust `.libPaths`.

# COMMAND ----------

# MAGIC %md ### Step 1: Install the `renv` package.
# MAGIC
# MAGIC [`renv`](https://rstudio.github.io/renv/articles/renv.html) is designed to promote reproducibility amongst the scripts created by R users. As a nice bonus, it allows the establishment of a package cache, the location of which is specified with the environment variable `RENV_PATHS_CACHE`.
# MAGIC
# MAGIC Let's try it out. 

# COMMAND ----------

##########
# Run #1 #
##########

install.packages("renv")
library("renv")

# COMMAND ----------

# MAGIC %md Check: is the cache path set correctly?

# COMMAND ----------

renv::paths$cache()

# COMMAND ----------

# MAGIC %md (Just for this test) manually update to point to a DBFS location accessible for all users.

# COMMAND ----------

Sys.setenv(RENV_PATHS_CACHE = "/dbfs/Users/<your_user>/<path_to_folder>")
renv::paths$cache()

# COMMAND ----------

# MAGIC %md ### Step 2: Install the target package
# MAGIC
# MAGIC The first time this will require building from source, but it will cache the compiled binary to speed things up the next time around.

# COMMAND ----------

renv::install("arrow")

# COMMAND ----------

# MAGIC %md ### Step 3: Automate
# MAGIC
# MAGIC So that users don't have to install the library and set these options each time they go to do their work, do the following:
# MAGIC - Pin the `renv` library [to the cluster](https://docs.databricks.com/en/libraries/package-repositories.html#cran-libraries); 
# MAGIC - Update the [cluster config](https://docs.databricks.com/en/clusters/configure.html#environment-variables) to include the `RENV_PATHS_CACHE` environment variable; and
# MAGIC - Restart

# COMMAND ----------

# MAGIC %md ### Run #2

# COMMAND ----------

renv::install("arrow")

# COMMAND ----------

# MAGIC %md < 10s vs. 6mins

# COMMAND ----------

# MAGIC %md Don't forget to tell users to use `renv::install()` instead of `install.packages()`.
