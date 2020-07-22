##########################################
#   Load packages
##########################################
#Public packages
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
import re

PYTHONPATH = sys.path.insert(0, os.getcwd())
from db import connections as connections
from db import qryhelper as qryhelper
from model import inputs as inputs
from model import scoring as scoring

##########################################
#   Connect to servers
##########################################
#Connect to hhsaw
hhsaw_engine = connections.hhsaw_engine()
hhsaw = hhsaw_engine.connect()

#Speed up table loading
@event.listens_for(hhsaw_engine, 'before_cursor_execute')
def receive_before_cursor_execute(hhsaw, cursor, statement,
    params, context, executemany):
    if executemany:
        cursor.fast_executemany = True
        cursor.commit()

#Connect to php96
php96_engine = connections.php96_engine()
php96 = php96_engine.connect()

#Speed up table loading
@event.listens_for(php96_engine, 'before_cursor_execute')
def receive_before_cursor_execute(php96, cursor, statement,
    params, context, executemany):
    if executemany:
        cursor.fast_executemany = True
        cursor.commit()

#Connect to phclaims
phclaims_engine = connections.phclaims_engine()
phclaims = phclaims_engine.connect()

#Speed up table loading
@event.listens_for(phclaims_engine, 'before_cursor_execute')
def receive_before_cursor_execute(phclaims, cursor, statement,
    params, context, executemany):
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
#   Get clients and inputs
##########################################
dat = inputs.get_clients(php96, pop_start, pop_end)
dat2 = inputs.get_locus(dat, php96, calc_date)
dat3 = inputs.get_calocus(dat2, php96, calc_date)
dat4 = inputs.get_foster(dat3, php96, calc_date)
dat5 = inputs.get_homeless(dat4, php96, calc_date)
dat6 = inputs.get_chronic_conditions(dat5, php96, phclaims, calc_date)
dat7 = inputs.get_high_util(dat6, hhsaw, calc_date)
dat8 = inputs.get_cj(dat7, php96, inputs.get_jail_date(calc_date, php96))
dat9 = inputs.get_asam(dat8, php96, calc_date)
dat10 = inputs.get_idu(dat9, php96, calc_date)

#Now, score each model metric and create total score for each client
score_lines = scoring.get_score_lines(dat10, php96, calc_date)
#total_score =

######
df_client = dat10
df_score = lul
conn = php96
id_cols = ['auth_no', 'program', 'age_group', 'calc_date']
sum_vals = {'score': 'sum', 'missing_data': 'max'}
df_client_grp = df_score.groupby(id_cols).agg(sum_vals).reset_index()
df_client_grp.to_sql('#phs_strat_level', conn)
sql = qryhelper.get_query('phs_strat_level.sql')
sql_out = pd.read_sql(sql, conn)

######
test_that_dat = df_client_grp.groupby('program').agg({'score': 'mean'}).reset_index()
print(test_that_dat)
print(dat10.columns)


print(lul)
print(dat9.shape)
print(dat10.shape)
print(lul.shape)
print(dat10.columns)
print(lul.columns)
