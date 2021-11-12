FROM continuumio/miniconda3:4.9.2 as gdal-build

RUN apt-get --allow-releaseinfo-change update && \
    apt-get install -y wget bzip2 unzip gcc bison flex make g++ pkg-config \
                      libreadline-dev zlib1g-dev libcfitsio-dev libgeos-dev libopenjp2-7-dev libtiff-dev libpq-dev \
                      sqlite3 libsqlite3-dev libtiff5-dev libzstd-dev curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV PGC_GDAL_INSTALL_ROOT=/opt/pgc
RUN mkdir -p $PGC_GDAL_INSTALL_ROOT

WORKDIR /tmp/proj_build

RUN wget https://download.osgeo.org/proj/proj-7.2.0.tar.gz && \
    tar xvzf proj-7.2.0.tar.gz && \
    cd proj-7.2.0 && \
    ./configure --without-curl --prefix=$PGC_GDAL_INSTALL_ROOT/proj && make && make install

ENV LD_LIBRARY_PATH=$PGC_GDAL_INSTALL_ROOT/proj/lib:$LD_LIBRARY_PATH

WORKDIR /opt/pgc

RUN wget -q https://github.com/Esri/file-geodatabase-api/raw/master/FileGDB_API_1.5.1/FileGDB_API_1_5_1-64gcc51.tar.gz && \
    tar -zxf  FileGDB_API_1_5_1-64gcc51.tar.gz -C $PGC_GDAL_INSTALL_ROOT/
ENV LD_LIBRARY_PATH=$PGC_GDAL_INSTALL_ROOT/FileGDB_API-64gcc51/lib:$LD_LIBRARY_PATH

WORKDIR /tmp/gdal_build
ENV gdal_version=3.1.2
RUN wget --no-check-certificate -q \
    http://download.osgeo.org/gdal/$gdal_version/gdal-$gdal_version.tar.gz && \
    tar xfz gdal-$gdal_version.tar.gz

WORKDIR /tmp/gdal_build/gdal-$gdal_version
RUN ./configure --prefix=$PGC_GDAL_INSTALL_ROOT/gdal \
    --with-proj=$PGC_GDAL_INSTALL_ROOT/proj \
    --with-geos \
    --with-cfitsio \
    --with-pg=yes \
    --without-python \
    --with-openjpeg \
    --with-fgdb=$PGC_GDAL_INSTALL_ROOT/FileGDB_API-64gcc51 \
    --with-lerc \
    --with-zstd \
    --with-libtiff=internal \
    --with-geotiff=internal \
    --with-rename-internal-libtiff-symbols=yes \
    --with-rename-internal-libgeotiff-symbols=yes \
    --with-sqlite3=no | tee /tmp/gdal_build/configure.log

RUN make -j 8 | tee /tmp/gdal_build/make.log
ENV PYTHONPATH=$PGC_GDAL_INSTALL_ROOT/gdal-python/lib/python:$PYTHONPATH
RUN make install | tee /tmp/gdal_build/install.log
RUN cd swig/python && \
    mkdir -p $PGC_GDAL_INSTALL_ROOT/gdal-python/lib/python && \
    python setup.py install --home $PGC_GDAL_INSTALL_ROOT/gdal-python | tee /tmp/gdal_build/gdal-python-install.log

FROM continuumio/miniconda3:4.9.2

MAINTAINER imxxx021@umn.edu

RUN apt-get --allow-releaseinfo-change update && \
    apt-get install -y libreadline-dev zlib1g-dev libcfitsio-dev libgeos-dev libproj-dev libopenjp2-7-dev libtiff-dev libpq-dev \
        libsqlite3-dev libtiff5-dev libzstd-dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV gdal_version=3.1.2
ENV  PGC_GDAL_INSTALL_ROOT /opt/pgc
ENV  PYTHONPATH=$PGC_GDAL_INSTALL_ROOT/gdal-python/lib/python:$PYTHONPATH
ENV  PATH=$PGC_GDAL_INSTALL_ROOT/gdal/bin:$PGC_GDAL_INSTALL_ROOT/gdal-python/bin:$PATH
ENV  GDAL_DATA=$PGC_GDAL_INSTALL_ROOT/gdal/share/gdal
ENV  LD_LIBRARY_PATH=$PGC_GDAL_INSTALL_ROOT/gdal/lib:$PGC_GDAL_INSTALL_ROOT/FileGDB_API-64gcc51/lib:$PGC_GDAL_INSTALL_ROOT/proj/lib:$LD_LIBRARY_PATH

COPY --from=gdal-build $PGC_GDAL_INSTALL_ROOT/ $PGC_GDAL_INSTALL_ROOT/
COPY --from=gdal-build /tmp/gdal_build /tmp/gdal_build

# The setup script for the python bindings builds an egg which needs to be installed via easy_install.
# However, easy_install is deprecated and setuptools removed it in v52.0.0 in favor of pip, and which apparently does not support eggs.
RUN easy_install GDAL==$gdal_version
RUN conda install numpy

CMD /bin/bash
