FROM python:3.11-slim

RUN pip install --no-cache-dir snappass

COPY templates/ /tmp/adp-templates/
COPY static/    /tmp/adp-static/

RUN SNAPPASS_DIR=$(python3 -c "import snappass, os; print(os.path.dirname(snappass.__file__))") && \
    cp /tmp/adp-templates/*.html "$SNAPPASS_DIR/templates/" && \
    cp /tmp/adp-static/snappass/css/custom.css "$SNAPPASS_DIR/static/snappass/css/custom.css" && \
    rm -rf /tmp/adp-templates /tmp/adp-static

EXPOSE 5000
CMD ["snappass"]
