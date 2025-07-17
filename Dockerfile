FROM amazonlinux:2

# Set up working directories
WORKDIR /opt/app
RUN mkdir -p /opt/app/build /opt/app/bin /opt/app/python

# Copy in the lambda source and requirements
COPY ./*.py ./
COPY requirements.txt .

# Install dependencies and ClamAV
RUN yum update -y && \
    amazon-linux-extras install epel -y && \
    yum clean all && \
    yum makecache && \
    yum install -y \
      python3 \
      python3-pip \
      yum-utils \
      cpio \
      zip \
      unzip \
      less \
      clamav \
      clamav-lib \
      clamav-update \
      json-c \
      pcre2 \
      libprelude \
      gnutls \
      libtasn1 \
      nettle \
      libtool-ltdl

# Ensure pip is up to date and install Python packages *only into local path*
RUN python3 -m pip install --upgrade pip && \
    pip3 install --no-cache-dir -r requirements.txt --target /opt/app/python

# Copy ClamAV binaries and dependencies
RUN cp /usr/bin/clamscan /usr/bin/freshclam /opt/app/bin/ && \
    find /usr/lib64 -maxdepth 1 -type f -exec cp {} /opt/app/bin/ \;

# Configure ClamAV
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf && \
    echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Package Lambda function and dependencies, excluding test files
WORKDIR /opt/app

# Add source code and ClamAV tools
RUN zip -r9 build/lambda.zip *.py bin \
    -x "*test*" "*tests/*" "*__pycache__*" "*.pyc"

# Add Python dependencies
WORKDIR /opt/app/python
RUN zip -r9 /opt/app/build/lambda.zip . \
    -x "*test*" "*tests/*" "*__pycache__*" "*.pyc"
