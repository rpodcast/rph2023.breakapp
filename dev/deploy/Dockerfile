FROM rph2023.breakapp_base
COPY renv.lock.prod renv.lock
RUN R -e 'renv::restore()'
COPY rph2023.breakapp_*.tar.gz /app.tar.gz
RUN R -e 'remotes::install_local("/app.tar.gz",upgrade="never")'
RUN rm /app.tar.gz
EXPOSE 80
EXPOSE 2550
EXPOSE 5432
EXPOSE 25060
CMD R -e "options('shiny.port'=2550,auth0_config_file = system.file('app/_auth0.yml',package = 'rph2023.breakapp'),auth0_disable=FALSE,shiny.host='0.0.0.0');library(rph2023.breakapp);rph2023.breakapp::run_app()"
