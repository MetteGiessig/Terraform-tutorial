import os
import json
import uuid

import dateutil.parser

import logging
from opencensus.ext.azure.log_exporter import AzureLogHandler

from azure.servicebus import ServiceBusClient, ServiceBusMessage
from azure.storage.filedatalake import DataLakeServiceClient

from dotenv import load_dotenv
load_dotenv()

# get Enviroment variables
AZURE_LOG_CONNECTION_STRING = os.getenv("AZURE_LOG_CONNECTION_STRING")
AZURE_QUEUE_CONNECTION_STRING = os.getenv("AZURE_QUEUE_CONNECTION_STRING")
TOPIC_NAME = os.getenv("TOPIC_NAME")
SUBSCRIPTION_NAME = os.getenv("SUBSCRIPTION_NAME")

storage_account_name = os.getenv("storage_account_name")
storage_account_key = os.getenv("storage_account_key")

# Azure Application Insights settings - Logging
properties = {'custom_dimensions': {'TopicName': TOPIC_NAME, 'integrationName': 'Dataflow-queue'}}

logger = logging.getLogger(__name__)
logger.setLevel(level=logging.INFO)
logger.addHandler(AzureLogHandler(connection_string=AZURE_LOG_CONNECTION_STRING))
logger = logging.LoggerAdapter(logger, properties)

# Send message for testing only
def send_single_message(sender, msg):
    '''Sends a message to the topic queue'''

    # create a Service Bus message
    message = ServiceBusMessage(json.dumps(msg))

    # send the message to the topic
    sender.send_messages(message)

def load_to_datalake(msg):
    '''Creates a file in the datalake at the location eventType/yyyy/MM/dd/HH/random_dataFile.json'''
    
    lake_path = ""
    file_name = uuid.uuid4().hex

    # Convert the ServiceBusMessaged to dict
    body_dict = {}
    body_dict = json.loads(str(msg))

    #Extracting the data and the meta data
    data=body_dict["data"]

    meta = {}
    meta = body_dict["meta"]
    eventdate = dateutil.parser.parse(meta["timestamp"])

      #Formats a file path like this eventType/yyyy/MM/dd/HH/random_dataFile.json
    lake_path = "{}/{}/{:02d}/{:02d}/{:02d}/{}.json".format(
        body_dict["type"],
        eventdate.year,
        eventdate.month,
        eventdate.day,
        eventdate.hour,
        file_name
        )

    # Create a client to communicate with the datalake
    service_client = DataLakeServiceClient(account_url="https://{}.dfs.core.windows.net".format(
            storage_account_name), credential=storage_account_key)
    file_system_client = service_client.get_file_system_client(file_system="flu-dev-datalake-fs")
    directory_client = file_system_client.get_directory_client("data")

    # Encode the date to Bytes
    encode_data = json.dumps(data).encode('utf-8')
    
    # Create a file and loads the data into it
    file_client = directory_client.create_file(lake_path)
    file_client.append_data(data=encode_data, offset=0, length=len(encode_data))
    file_client.flush_data(len(encode_data))

    return lake_path

def main():
    # create a Service Bus client using the connection string
    servicebus_client = ServiceBusClient.from_connection_string(conn_str=AZURE_QUEUE_CONNECTION_STRING, logging_enable=True)
        
    with servicebus_client:
        # get a Topic Sender object to send messages to the topic for testing
        sender = servicebus_client.get_topic_sender(topic_name=TOPIC_NAME)
        with sender: 
            DevEvent = {
              "type": "DevPageView",
              "meta": {
                "website": "https://flugger.dk",
                "shopId": "fluggerdk",
                "timestamp": "2022-02-01T08:22:04Z"
              },
              "user": {
                "id": "1234",
                "anonymousId": "c0664408-9c3a-4458-b37e-54f7bf27efff",
                "ip": "1.1.1.1",
                "userAgent": "Mozilla/5.0"
              },
              "data": {
                "url": "https://www.flugger.dk/inspiration-guide/farver-til-dit-hjem/",
                "title": "Farver til dit hjem | Farvekort, magasiner og inspiration"
              }
            }

            # for i in range(11):
            #     send_single_message(sender, DevEvent) 

        while True:
            # get the Subscription Receiver object  
            receiver = servicebus_client.get_subscription_receiver(topic_name=TOPIC_NAME, subscription_name=SUBSCRIPTION_NAME, max_wait_time=5)
            with receiver:
                for msg in receiver:
                    logger.info(f"Queue Flow: Received message from queue: {msg}")
                    
                    #Load to data lake storage
                    data_lake_path = load_to_datalake(msg)

                    logger.info(f"Queue Flow: Created file at - {data_lake_path}")

                    # complete the message so that the message is removed from the subscription
                    receiver.complete_message(msg)

if __name__ == "__main__":
    main()