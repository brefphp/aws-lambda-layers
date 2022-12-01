FROM public.ecr.aws/lambda/provided:al2-x86_64

# yum-utils installs the yum-config-manager command
RUN yum install -y \
        https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
        https://rpms.remirepo.net/enterprise/remi-release-7.rpm \
        yum-utils \
        epel-release \
        curl

# Install development tools to compile extra PHP extensions
RUN yum groupinstall -y "Development Tools"
