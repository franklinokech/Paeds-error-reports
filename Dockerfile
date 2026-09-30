FROM rocker/r-ver:4.1.2

ENV DEBIAN_FRONTEND=noninteractive
ENV RENV_CONFIG_CACHE_ENABLED=FALSE
ENV RENV_CONFIG_SANDBOX_ENABLED=FALSE

# System libraries needed by your R packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libicu-dev \
    libgit2-dev \
    libssh2-1-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libpng-dev \
    libtiff-dev \
    libjpeg-dev \
    libx11-dev \
    libharfbuzz-dev \
    libfribidi-dev \
    pandoc \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install renv globally
RUN R -q -e 'install.packages("renv", repos="https://cloud.r-project.org")'

WORKDIR /app

# Only the lockfile at build time; source code comes from bind mounts at runtime
COPY renv.lock renv.lock

# Create the paths that the named volumes will be mounted onto
RUN mkdir -p /renv-library /renv-cache /app/tmp

# Restore packages from the lockfile into the shared library volume path.
# devtools / testthat / waldo are excluded because they are dev-only and
# waldo 0.3.1 fails to lazy-load under R 4.1.x.
ARG GITHUB_PAT
RUN GITHUB_PAT=$GITHUB_PAT R -q -e 'renv::restore(prompt = FALSE, library = "/renv-library", exclude = c("devtools","testthat","waldo"))'

# Install RedcapData via remotes (much smaller than devtools; does not pull
# in waldo/testthat). This replaces the devtools::install_github() call in
# 00-main.R.
RUN R -q -e 'install.packages("remotes", repos="https://cloud.r-project.org")' \
 && GITHUB_PAT=$GITHUB_PAT R -q -e 'remotes::install_github("smockin/RedcapData", ref = "v1.1.1", upgrade = "never", dependencies = TRUE)'

# Sanity check that the key packages are visible to base R
RUN R -q -e 'stopifnot("RedcapData" %in% rownames(installed.packages())); cat("RedcapData OK\n")'

CMD ["Rscript", "00-main.R"]