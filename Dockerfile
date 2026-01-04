FROM rayproject/ray:nightly-extra

RUN pip install rayai

WORKDIR /app

COPY start-ray-agent.sh /app/start-ray-agent.sh

RUN chmod +x /app/start-ray-agent.sh

EXPOSE 8200 8265

CMD ["/app/start-ray-agent.sh"]