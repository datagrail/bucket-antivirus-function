FROM amazonlinux:2

# Set up working directories
WORKDIR /opt/app
RUN mkdir -p /opt/app/build /opt/app/bin /opt/app/python

# Copy in the source and requirements
COPY ./*.py ./
COPY requirements.txt .

# Install system dependencies and ClamAV
RUN yum update -y && \
  amazon-linux-extras install epel -y && \
  yum clean all && \
  yum makecache && \
  yum install -y yum-utils cpio python3-pip zip unzip less \
    clamav clamav-lib clamav-update json-c pcre2 libprelude \
    gnutls libtasn1 nettle libtool-ltdl

# Install Python packages into /opt/app/python (Lambda looks here when unpacking ZIPs)
RUN pip3 install --upgrade pip && \
  pip3 install -r requirements.txt --target /opt/app/python && \
  rm -rf /root/.cache/pip

# Copy binaries for ClamAV
RUN cp /usr/bin/clamscan /usr/bin/freshclam /opt/app/bin/ && \
  find /usr/lib64 -maxdepth 1 -type f -exec cp {} /opt/app/bin/ \;

# Configure ClamAV
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf && \
    echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf

# Create the Lambda zip file
WORKDIR /opt/app

# Start with code and bin/
RUN zip -r9 --exclude="*test*" build/lambda.zip *.py bin

# Add site-packages
WORKDIR /opt/app/python
RUN zip -r9 /opt/app/build/lambda.zip .
