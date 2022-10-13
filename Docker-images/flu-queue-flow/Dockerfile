FROM python:3

ADD requirements.txt /
RUN pip install -r requirements.txt
ADD run.py /
ADD .env /

CMD [ "python", "./run.py"]