#! /usr/bin/python

from socket import socket,AF_INET,SOCK_DGRAM,SO_REUSEADDR,SOL_SOCKET
from time import sleep,ctime
import sys
if len(sys.argv)>2:
    localIP = sys.argv[1]
    localPort = int(sys.argv[2])
bufSize = 1500
sock = socket(family=AF_INET, type=SOCK_DGRAM)
sock.setsockopt(SOL_SOCKET,SO_REUSEADDR, 1)
sock.bind((localIP, localPort))
while True:
    message, ipport = sock.recvfrom(bufSize)
