from azure.servicebus import ServiceBusClient, ServiceBusMessage
import time

CONNECTION_STR = "REPLACEME"
TOPIC_NAME = "REPLACEME"

print("Starting to send messages")
print("-----------------------")

def send_single_message(sender):
    message_str = f"Single Message {time.time()}"
    message = ServiceBusMessage(message_str)
    sender.send_messages(message)
    print(f"Sent a single message: {message_str}")

servicebus_client = ServiceBusClient.from_connection_string(conn_str=CONNECTION_STR, logging_enable=True)
with servicebus_client:
    sender = servicebus_client.get_topic_sender(topic_name=TOPIC_NAME)
    with sender:
        send_single_message(sender)

print("Done sending messages")
print("-----------------------")
