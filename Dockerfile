
# Use the official AWS Lambda Python 3.11 base image
FROM public.ecr.aws/lambda/python:3.11


# Set up working directories
RUN mkdir -p /opt/app/build /opt/app/bin

# Copy in the lambda source
WORKDIR /opt/app
COPY ./*.py ./
COPY requirements.txt ./

# Install dependencies
RUN pip3 install --upgrade pip && pip3 install -r requirements.txt --target .

# Install system packages needed for ClamAV and others
RUN yum install -y zip unzip less clamav clamav-lib clamav-update json-c pcre2 libprelude gnutls libtasn1 nettle libtool-ltdl binutils



# Clean up pip cache
RUN rm -rf /root/.cache/pip


# Copy over the binaries and libraries
WORKDIR /tmp
RUN cp /usr/bin/clamscan /usr/bin/freshclam /usr/bin/ld /opt/app/bin/ && \
  find /usr/lib64 -maxdepth 1 -type f -exec cp {} /opt/app/bin/ \;
# Fix the freshclam.conf settings
RUN echo "DatabaseMirror database.clamav.net" > /opt/app/bin/freshclam.conf
RUN echo "CompressLocalDatabase yes" >> /opt/app/bin/freshclam.conf


# Create the zip file
WORKDIR /opt/app
RUN zip -r9 --exclude="*test*" /opt/app/build/lambda.zip .