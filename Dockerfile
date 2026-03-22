FROM python:3.11-slim

RUN pip install --no-cache-dir snappass

COPY templates/ /tmp/adp-templates/
COPY static/    /tmp/adp-static/

RUN SNAPPASS_DIR=$(python3 -c "import snappass, os; print(os.path.dirname(snappass.__file__))") && \
    echo "==> SNAPPASS_DIR: $SNAPPASS_DIR" && \
    echo "==> Templates BEFORE copy:" && \
    ls "$SNAPPASS_DIR/templates/" && \
    echo "==> Our templates to copy:" && \
    ls /tmp/adp-templates/ && \
    cp -v /tmp/adp-templates/*.html "$SNAPPASS_DIR/templates/" && \
    cp -v /tmp/adp-static/snappass/css/custom.css "$SNAPPASS_DIR/static/snappass/css/custom.css" && \
    echo "==> Templates AFTER copy:" && \
    ls "$SNAPPASS_DIR/templates/" && \
    rm -rf /tmp/adp-templates /tmp/adp-static

EXPOSE 5000
CMD ["snappass"]
