FROM continuumio/miniconda2:4.7.12 AS gdal-build

RUN apt-get update && \
    apt-get install -y wget bzip2 unzip gcc bison flex make g++ \
                      libreadline-dev zlib1g-dev libcfitsio-dev libgeos-dev libproj-dev libopenjp2-7-dev libtiff-dev libpq-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV PGC_GDAL_INSTALL_ROOT /opt/pgc
RUN mkdir -p $PGC_GDAL_INSTALL_ROOT

WORKDIR /tmp/gdal_build

RUN wget -q https://github.com/Esri/file-geodatabase-api/raw/master/FileGDB_API_1.5.1/FileGDB_API_1_5_1-64gcc51.tar.gz && \
    tar -zxf  FileGDB_API_1_5_1-64gcc51.tar.gz -C $PGC_GDAL_INSTALL_ROOT/
ENV LD_LIBRARY_PATH=$PGC_GDAL_INSTALL_ROOT/FileGDB_API-64gcc51/lib:$LD_LIBRARY_PATH

ENV gdal_version 2.3.2
RUN wget --no-check-certificate -q \
    http://download.osgeo.org/gdal/$gdal_version/gdal-$gdal_version.tar.gz && \
    tar xfz gdal-$gdal_version.tar.gz

WORKDIR /tmp/gdal_build/gdal-$gdal_version
RUN ./configure --prefix=$PGC_GDAL_INSTALL_ROOT/gdal \
    --with-proj \
    --with-geos \
    --with-cfitsio \
    --with-pg=/usr/bin/pg_config \
    --with-python \
    --with-openjpeg \
    --with-fgdb=$PGC_GDAL_INSTALL_ROOT/FileGDB_API-64gcc51 \
    --with-sqlite3=no | tee /tmp/gdal_build/configure.log

RUN make -j 8 | tee /tmp/gdal_build/make.log
ENV  PYTHONPATH=$PGC_GDAL_INSTALL_ROOT/gdal-python/lib/python:$PYTHONPATH
RUN make install | tee /tmp/gdal_build/install.log && \
    cd swig/python && \
    mkdir -p $PGC_GDAL_INSTALL_ROOT/gdal-python/lib/python && \
    python setup.py install --home $PGC_GDAL_INSTALL_ROOT/gdal-python | tee /tmp/gdal_build/gdal-python-install.log

FROM continuumio/miniconda2:4.7.12

MAINTAINER azenk@umn.edu

RUN apt-get update && \
    apt-get install -y libreadline-dev zlib1g-dev libcfitsio-dev libgeos-dev libproj-dev libopenjp2-7-dev libtiff-dev libpq-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN conda update -n base conda && \
    conda install --yes pip && \
    conda clean --all --yes

ENV  PGC_GDAL_INSTALL_ROOT /opt/pgc
ENV  PYTHONPATH=$PGC_GDAL_INSTALL_ROOT/gdal-python/lib/python:$PYTHONPATH
ENV  PATH=$PGC_GDAL_INSTALL_ROOT/gdal/bin:$PGC_GDAL_INSTALL_ROOT/gdal-python/bin:$PATH
ENV  GDAL_DATA=$PGC_GDAL_INSTALL_ROOT/gdal/share/gdal
ENV  LD_LIBRARY_PATH=$PGC_GDAL_INSTALL_ROOT/gdal/lib:$PGC_GDAL_INSTALL_ROOT/FileGDB_API-64gcc51/lib:$LD_LIBRARY_PATH

COPY --from=gdal-build $PGC_GDAL_INSTALL_ROOT/ $PGC_GDAL_INSTALL_ROOT/

CMD /bin/bash
