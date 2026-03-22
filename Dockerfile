FROM python:3.11-slim

RUN pip install --no-cache-dir snappass

# Find where snappass installed its templates/static and override with our branded versions
RUN python -c "import snappass, os; print(os.path.dirname(snappass.__file__))" > /snappass_path.txt

COPY templates/ /usr/local/lib/python3.11/site-packages/snappass/templates/
COPY static/    /usr/local/lib/python3.11/site-packages/snappass/static/

EXPOSE 5000
CMD ["snappass"]
