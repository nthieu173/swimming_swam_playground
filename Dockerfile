FROM gazebo:libgazebo8-xenial

RUN apt-get update && apt-get install --no-install-recommends -y \
  cmake \
  build-essential \
  ca-certificates \
  curl \
  git \
  lsb-release \
  python-all-dev \
  python-pip \
  python-setuptools \
  python-wheel \
  sudo \
  software-properties-common \
  && rm -rf /var/lib/apt/lists/*

RUN git clone -b custom-6-dof https://github.com/nthieu173/ardupilot.git /ardupilot

WORKDIR /ardupilot

RUN git submodule update --init --recursive

# Build Ardupilot

ARG DEBIAN_FRONTEND=noninteractive
RUN useradd -U -m ardupilot \
  && usermod -G users ardupilot

# Create non root user for pip
ENV USER=ardupilot

RUN echo "ardupilot ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ardupilot
RUN chmod 0440 /etc/sudoers.d/ardupilot

RUN chown -R ardupilot:ardupilot /ardupilot

USER ardupilot

ENV SKIP_AP_EXT_ENV=1 SKIP_AP_GRAPHIC_ENV=1 SKIP_AP_COV_ENV=1 SKIP_AP_GIT_CHECK=1

RUN pip install future lxml
RUN Tools/environment_install/install-prereqs-ubuntu.sh -y

# add waf alias to ardupilot waf to .bashrc
RUN echo "alias waf=\"/ardupilot/waf\"" >> ~/.bashrc

# Check that local/bin are in PATH for pip --user installed package
RUN echo "if [ -d \"\$HOME/.local/bin\" ] ; then\nPATH=\"\$HOME/.local/bin:\$PATH\"\nfi" >> ~/.bashrc

# Set the buildlogs directory into /tmp as other directory aren't accessible
ENV BUILDLOGS=/tmp/buildlogs

# Cleanup
RUN sudo apt-get clean \
  && sudo rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV CCACHE_MAXSIZE=1G

RUN ./waf configure --board SITL_x86_64_linux_gnu \
  && ./waf sub

USER root

RUN git clone https://github.com/patrickelectric/ardupilot_gazebo.git /ardupilot_gazebo

WORKDIR /ardupilot_gazebo/build

RUN cmake .. \
  && make -j4 \
  && make install

RUN git clone https://github.com/bluerobotics/freebuoyancy_gazebo.git /freebuoyancy_gazebo

RUN sed -i '/#include <urdf_parser\/urdf_parser.h>/d' /freebuoyancy_gazebo/src/freebuoyancy.cpp

WORKDIR /freebuoyancy_gazebo/build

RUN cmake .. \
  && make \
  && make install

ADD model/ /model

ADD worlds/ /worlds

WORKDIR /

ENV GAZEBO_PLUGIN_PATH=/ardupilot_gazebo/build

ENV GAZEBO_MODEL_PATH=/model

ENV GAZEBO_RESOURCE_PATH=/worlds

CMD ["gzserver", "--verbose", "/worlds/underwater.world"]
