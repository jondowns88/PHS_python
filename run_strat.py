import os
import sys
import pandas as pd
import numpy as np
from sqlalchemy import create_engine, event
import urllib
from dateutil.relativedelta import relativedelta
import datetime
import math
import sqlparams

#Import library for this project
PYTHONPATH = sys.path.insert(0, os.getcwd())
from model import get_clients as model

##########################################
#   Connect to server
##########################################
#Make connection string
conn_string = urllib.parse.quote_plus("DRIVER={SQL Server Native client 11.0};"
                                r"SERVER=KCITEC2SQEPRP;DATABASE=php96;"
                                r"Trusted_Connection=yes;MultiSubnetFailover=Yes;")

#Connect to php96
engine = create_engine("mssql+pyodbc:///?odbc_connect=%s" % conn_string)
conn = engine.connect()

#I have no idea what this does, but the internet says it speeds up creation of temp tabs
@event.listens_for(engine, 'before_cursor_execute')
def receive_before_cursor_execute(conn, cursor, statement, params, context, executemany):
    if executemany:
        cursor.fast_executemany = True
        cursor.commit()

##########################################
#   Define key dates
##########################################
calc_date = datetime.date.today() #Calculation date
#calc_date = datetime.date(year = 2020, month = 6, day = 30)
pop_start = datetime.date(year=calc_date.year, #first day of qtr
    month=((math.floor(((calc_date.month - 1) / 3) + 1) - 1) * 3) + 1,
    day=1)
pop_end = pop_start + relativedelta(months = +3, days = -1)
sda_start = pop_start + relativedelta(months = -4)
sda_end = sda_start + relativedelta(months = +3, days = -1)

##########################################
#   Get clients, run strat model
##########################################
dat = model.get_clients(conn, pop_start, pop_end)
dat2 = model.get_locus(dat, conn, calc_date = calc_date)
dat3 = model.get_calocus(dat2, conn, calc_date = calc_date)
print(dat2.shape)
print(dat3.shape)
print(list(dat2.columns))
print(list(dat3.columns))
