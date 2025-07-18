
# Use the official AWS Lambda Python 3.11 base image

FROM public.ecr.aws/lambda/python:3.11


# Set up working directories

RUN mkdir -p /opt/app/build /opt/app/bin

# Copy in the lambda source

WORKDIR /opt/app
COPY ./*.py ./
COPY requirements.txt ./

# Install dependencies

# Install Python dependencies into the deployment package
RUN pip3 install --upgrade pip && pip3 install -r requirements.txt --target .

# Install system packages needed for ClamAV and others

# Install ClamAV and all required system libraries
RUN yum install -y zip unzip less clamav clamav-lib clamav-update json-c pcre2 libprelude gnutls libtasn1 nettle libtool-ltdl



# Clean up pip cache

RUN rm -rf /root/.cache/pip


# Copy over the binaries and libraries

# Copy ClamAV binaries and all required shared libraries
WORKDIR /tmp
RUN cp /usr/bin/clamscan /usr/bin/freshclam /opt/app/bin/ && \
  ldd /usr/bin/clamscan | awk '{print $3}' | grep -E '^/' | xargs -I '{}' cp -v '{}' /opt/app/bin/ && \
  ldd /usr/bin/freshclam | awk '{print $3}' | grep -E '^/' | xargs -I '{}' cp -v '{}' /opt/app/bin/ && \
  find /usr/lib64 -maxdepth 1 -type f -name 'libclamav*' -exec cp -v {} /opt/app/bin/ \;

# Fix the freshclam.conf settings

# Set up freshclam.conf for definition updates
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf && \
  echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf


# Create the zip file

# Package everything into the Lambda deployment zip
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" build/lambda.zip .