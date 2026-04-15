FROM ubuntu:22.04

# Avoid interactive prompts during build
ENV DEBIAN_FRONTEND=noninteractive

# Install SSH server, Python 3, sudo, and useful utilities
RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    sudo \
    curl \
    vim \
    net-tools \
    iputils-ping \
    && rm -rf /var/lib/apt/lists/*

# Create the Ansible service account used in Module 3 exercises
# (This account already exists so students can verify idempotency)
RUN groupadd svc-accounts && \
    useradd -m -s /bin/bash -G svc-accounts svc-ansible && \
    usermod -L svc-ansible

# Create the labadmin user with sudo access
# Ansible will connect as this user using the lab SSH key
RUN useradd -m -s /bin/bash labadmin && \
    echo 'labadmin ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Configure SSH
RUN mkdir /var/run/sshd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Install the lab SSH public key for the labadmin user
RUN mkdir -p /home/labadmin/.ssh && \
    chmod 700 /home/labadmin/.ssh && \
    chown labadmin:labadmin /home/labadmin/.ssh

COPY lab_key.pub /home/labadmin/.ssh/authorized_keys
RUN chmod 600 /home/labadmin/.ssh/authorized_keys && \
    chown labadmin:labadmin /home/labadmin/.ssh/authorized_keys

# Create directories used in course exercises
RUN mkdir -p /etc/deploy && \
    mkdir -p /var/log/deploy && \
    chown labadmin:labadmin /var/log/deploy

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
