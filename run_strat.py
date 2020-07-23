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

#Packages in this module
PYTHONPATH = sys.path.insert(0, os.getcwd())
from db import connections as connections
from db import qryhelper as qryhelper
from model import inputs as inputs
from model import scoring as scoring
from model import sda as sda
from model import output as output

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
uid = 'jdowns'
pwd = input('Enter password (php96)')
php96_engine = connections.php96_engine(uid, pwd)
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
#   Get client data
##########################################
##Model inputs##
dat = inputs.get_clients(php96, pop_start, pop_end)
dat2 = inputs.get_locus(dat, php96, calc_date)
dat3 = inputs.get_calocus(dat2, php96, calc_date)
dat4 = inputs.get_foster(dat3, php96, calc_date)
dat5 = inputs.get_homeless(dat4, php96, calc_date)
dat6 = inputs.get_chronic_conditions(dat5, php96, phclaims, calc_date)
dat7 = inputs.get_high_util(dat6, hhsaw, calc_date)
dat8 = inputs.get_cj(dat7, php96, inputs.get_jail_date(calc_date, php96))
#ASAM only: ASAM not going to PHS, no need to run these.
#dat9 = inputs.get_asam(dat8, php96, calc_date)
#dat10 = inputs.get_idu(dat9, php96, calc_date)

##PHS scoring##
#One line per score
score_lines = scoring.get_score_lines(dat8, php96, calc_date)
#Total score for auth/quarter (with strat level)
total_score = scoring.get_total_score(dat8, score_lines, php96)

##SDA (final step before upload)##
#Drop auth start/end dates. Change name of PHS start/end for upload into PHP96.
drop_cols = ['start_date', 'expire_date']
all_data = sda.get_sda(total_score, php96, sda_start, sda_end).drop(columns = drop_cols)

##########################################
#   Create production tables, load production data
##########################################
#Grab columns that go into AU_STRATUM
au_stratum = output.get_au_stratum(all_data)

df_in = au_stratum
conn =


#Update AU_STRATUM in php96

#Next, grab columns that go into au_stratum_score
au_stratum_score_cols = ['metric', 'value', 'score', 'missing_data']
au_stratum_score = score_lines[au_stratum_score_cols]
