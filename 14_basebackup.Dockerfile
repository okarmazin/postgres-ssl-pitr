FROM postgres:14

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
  && rm -rf /var/lib/apt/lists/*

# Install Google Cloud SDK (gcloud/gsutil)
RUN curl -sSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor > /usr/share/keyrings/cloud.google.gpg \
  && echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" > /etc/apt/sources.list.d/google-cloud-sdk.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends google-cloud-cli \
  && rm -rf /var/lib/apt/lists/*

COPY --chmod=755 backup.sh /backup.sh

# clear the inherited entrypoint from the postgres image
# while it doesn't hurt, this is cleaner
ENTRYPOINT []
CMD ["/backup.sh"]