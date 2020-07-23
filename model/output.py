#Import other libraries
import pandas as pd
import numpy as np
import os
import sys
import pyodbc
import math
import datetime
from dateutil.relativedelta import relativedelta
import calendar
import sqlparams

PYTHONPATH = sys.path.insert(0, os.getcwd())
from db import qryhelper as qryhelper

#Create AU_STRATUM table
def get_au_stratum(df):
    rename_cols = {'phs_start_date': 'start_date', 'phs_end_date': 'end_date'}
    client_prod_data = df.rename(columns = rename_cols)
    au_stratum_cols = ['auth_no', 'calc_date', 'start_date', 'end_date',
        'total_score', 'strat_level', 'age_group',
        'special_population', 'language_differential', 'missing_data']
    au_stratum = client_prod_data[au_stratum_cols]
    #Initialize override status (not yet implemented, default to no overrides)
    au_stratum['override_status'] = 'NNN'
    return(au_stratum)

#Update AU_STRATUM in production
def update_au_stratum(df, conn):
    conn.execute('DROP TABLE IF EXISTS #au_stratum_temp')
    df.to_sql('#au_stratum_temp', conn)
    qry = qryhelper.get_query('update_au_stratum.sql')
    conn.execute(qry)

#Pulls AU_STRATUM_IDs from AU_STRATUM for merging with other datasets
def get_au_stratum_ids(start_date, conn):
    qry = qryhelper.get_query('phs_get_au_stratum_ids.sql')
    out = pd.read_sql(qry, conn, params = {start_date})
    return(out)

#Returns columns used in AU_STRATUM_SCORE (calling IDS from earlier qry)
def get_au_stratum_score(df, ids):
    keep_cols = ['au_stratum_id', 'metric', 'value', 'score', 'missing_data', 'override_ind']
    df_in = df.drop(df[df.metric == 'CHRON'].index)
    au_stratum_score = ids.merge(df_in, how = 'right')
    au_stratum_score['override_ind'] = 'N'
    return(au_stratum_score[keep_cols])

#Update AU_STRATUM_SCORE in production
def update_au_stratum_score(df, conn):
    conn.execute('DROP TABLE IF EXISTS #au_stratum_score_temp')
    df.to_sql('#au_stratum_score_temp', conn)
    qry = qryhelper.get_query('update_au_stratum_score.sql')
    conn.execute(qry)

#Get columns for upload to au_stratum_sda
def get_au_stratum_sda(df):
    rename_cols = {'phs_start_date': 'start_date', 'phs_end_date': 'end_date'}
    df_in = df.rename(columns = rename_cols)
    au_stratum_sda_cols = ['auth_no', 'start_date', 'end_date', 'sda', 'enroll_days',
        'hrs_expected', 'svc_hrs', 'svc_hrs_prorated', 'prev_auth_no']
    au_stratum_sda = df_in[au_stratum_sda_cols]
    return(au_stratum_sda)

#Update AU_STRATUM_SDA in production
def update_au_stratum_sda(df, conn):
    conn.execute('DROP TABLE IF EXISTS #au_stratum_sda_temp')
    df.to_sql('#au_stratum_sda_temp', conn)
    qry = qryhelper.get_query('update_au_stratum_sda.sql')
    conn.execute(qry)
