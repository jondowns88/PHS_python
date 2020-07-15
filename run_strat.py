#Import other libraries
import pandas as pd
import numpy as np
import os
import pyodbc
import sys

#Import library for this project
PYTHONPATH = sys.path.insert(0, os.getcwd())
from model import get_clients as model
conn = pyodbc.connect('DRIVER={SQL Server Native Client 11.0};SERVER=KCITEC2SQEPRP;DATABASE=php96;Trusted_Connection=yes;MultiSubnetFailover=Yes;')

dat = model.get_clients(conn, '2020-07-01', '2020-10-31')
print(dat)
