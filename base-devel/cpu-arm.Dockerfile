FROM public.ecr.aws/lambda/provided:al2-arm64

RUN yum install -y unzip curl

# Install development tools to compile extra PHP extensions
RUN yum groupinstall -y "Development Tools"
