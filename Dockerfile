FROM alpine:3.5
RUN apk add -U curl make bash

ENV KOPS_VERSION 1.8.1
RUN curl -LO https://github.com/kubernetes/kops/releases/download/${KOPS_VERSION}/kops-linux-amd64 \
    && mv kops-linux-amd64 /usr/bin/kops \
    && chmod +x /usr/bin/kops

ENV KUBECTL_VERSION 1.8.10
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && mv kubectl /usr/bin/kubectl \
    && chmod +x /usr/bin/kubectl

RUN echo "source <(kops completion bash)" >> ~/.bashrc
