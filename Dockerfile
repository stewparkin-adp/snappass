FROM python:3.11-slim

RUN pip install --no-cache-dir snappass

# Copy branded assets to a temp location, then move them to wherever
# pip actually installed snappass (path varies by Python minor version)
COPY templates/ /tmp/adp-templates/
COPY static/    /tmp/adp-static/

RUN SNAPPASS_DIR=$(python3 -c "import snappass, os; print(os.path.dirname(snappass.__file__))") && \
    cp -r /tmp/adp-templates/. "$SNAPPASS_DIR/templates/" && \
    cp -r /tmp/adp-static/.    "$SNAPPASS_DIR/static/" && \
    rm -rf /tmp/adp-templates /tmp/adp-static

EXPOSE 5000
CMD ["snappass"]
