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

#Get SDA for look-back period.
def get_sda(df, conn, start_date, end_date):
    id_cols = ['kcid', 'auth_no', 'program', 'age_group']
    df_in = df[id_cols]
    conn.execute("DROP TABLE IF EXISTS #phs_sda")
    df_in.to_sql('#phs_sda', conn, index = False)
    sql = qryhelper.get_query('phs_sda_calculation.sql')
    sp = sqlparams.SQLParams('named', 'qmark')
    sql2, params = sp.format(sql, {'start_date':start_date, 'end_date': end_date})
    sql_out = pd.read_sql(sql2, conn, params = params)
    na_fill = {'calendar_month': 0, 'enroll_days': 0, 'hrs_expected': 0,
        'svc_hrs': 0, 'svc_hrs_prorated': 0}
    out = df.merge(sql_out, how = 'left').fillna(na_fill)
    return(out)
