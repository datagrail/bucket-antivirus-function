FROM amazonlinux:2

# Set up working directories
RUN mkdir -p /opt/app
RUN mkdir -p /opt/app/build
RUN mkdir -p /opt/app/bin/

# Copy in the lambda source
WORKDIR /opt/app

COPY ./*.py /opt/app/
COPY requirements.txt /opt/app/requirements.txt

# Install packages and ClamAV
RUN yum update -y && \
  amazon-linux-extras install epel -y && \
  yum clean all && \
  yum makecache && \
  yum install -y yum-utils cpio python3-pip zip unzip less clamav clamav-lib clamav-update json-c pcre2 libprelude gnutls libtasn1 nettle libtool-ltdl

# This had --no-cache-dir, tracing through multiple tickets led to a problem in wheel
RUN pip3 install -r requirements.txt
RUN rm -rf /root/.cache/pip

# Copy over the binaries and libraries
WORKDIR /tmp
RUN cp /usr/bin/clamscan /usr/bin/freshclam /opt/app/bin/ && \
  find /usr/lib64 -maxdepth 1 -type f -exec cp {} /opt/app/bin/ \;

# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip *.py bin

RUN site_packages=$(python3 -c "import site; print(site.getsitepackages()[0])") && \
  cd "$site_packages" && \
  zip -r9 /opt/app/build/lambda.zip .

WORKDIR /opt/app