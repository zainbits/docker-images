FROM ubuntu:latest

# Update and install necessary packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y openssh-server nano && \
    mkdir /var/run/sshd

# Set root password
RUN echo 'root:yourpassword' | chpasswd

# Allow root login over SSH
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Expose ports
EXPOSE 22

# Start SSH service
CMD ["/usr/sbin/sshd", "-D"]
