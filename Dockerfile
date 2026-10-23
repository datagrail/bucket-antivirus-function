
# Use the official AWS Lambda Python 3.13 base image (Amazon Linux 2023). Lambda runs these
# functions on x86_64; `make archive` builds for linux/amd64 even on arm64 hosts.

FROM public.ecr.aws/lambda/python:3.13

# ClamAV comes from Cisco-Talos's official release RPM, not the distro: AL2023 only ships the
# end-of-life 0.103 LTS. Bump both together; the digest is on the GitHub release asset.
ARG CLAMAV_VERSION=1.4.6
ARG CLAMAV_RPM_SHA256=746feb3d9f1c2273c38fd9ac3129b2eafa358078870fef3d76afebf9a4bdd4ae


# Set up working directories

RUN mkdir -p /opt/app/build /opt/app/bin

# Copy in the lambda source

WORKDIR /opt/app
COPY ./*.py ./
COPY requirements.txt ./

# Install dependencies

# Install Python dependencies into the deployment package
RUN pip3 install --upgrade "pip>=26.2.2" && pip3 install -r requirements.txt --target .

# Install system packages needed for packaging and ClamAV

RUN dnf install -y zip unzip findutils && dnf clean all
RUN curl -fsSL -o /tmp/clamav.rpm \
    "https://github.com/Cisco-Talos/clamav/releases/download/clamav-${CLAMAV_VERSION}/clamav-${CLAMAV_VERSION}.linux.x86_64.rpm" && \
  echo "${CLAMAV_RPM_SHA256}  /tmp/clamav.rpm" | sha256sum -c - && \
  rpm -i /tmp/clamav.rpm && rm /tmp/clamav.rpm



# Clean up pip cache

RUN rm -rf /root/.cache/pip


# Copy over the binaries and libraries

# Copy ClamAV binaries and the shared libraries they need. glibc itself is skipped: the Lambda
# runtime provides it, and loading a second copy from LD_LIBRARY_PATH breaks the binaries.
WORKDIR /tmp
RUN cp /usr/local/bin/clamscan /usr/local/bin/freshclam /opt/app/bin/ && \
  ldd /usr/local/bin/clamscan /usr/local/bin/freshclam | awk '{print $3}' | grep -E '^/' | \
  grep -vE '/(libc|libm|libdl|libpthread|librt|libutil|libresolv|ld-linux[^/]*)\.so' | sort -u | \
  xargs -I '{}' cp -v '{}' /opt/app/bin/ && \
  LD_LIBRARY_PATH=/opt/app/bin /opt/app/bin/clamscan --version

# Fix the freshclam.conf settings

# Set up freshclam.conf for definition updates
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf && \
  echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf


# Create the zip file

# Package everything into the Lambda deployment zip
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" build/lambda.zip .
