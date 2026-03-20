FROM python:3.11-slim
RUN pip install --no-cache-dir snappass
EXPOSE 5000
CMD ["snappass"]
