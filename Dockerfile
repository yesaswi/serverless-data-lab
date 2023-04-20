FROM rocker/rstudio:latest

# Install system dependencies for MySQL and SQLite
RUN apt-get update && \
    apt-get install -y libmysqlclient-dev libsqlite3-dev

# Install R packages
RUN install2.r --error \
    RMySQL \
    RSQLite \
    ggplot2 \
    plotly

# Set environment variables for RStudio user and password
ENV USER rstudio
ENV PASSWORD Password123

# Expose port for RStudio Server
EXPOSE 8787
