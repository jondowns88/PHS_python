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

#Function to get one row per model input. Used to update au_stratum_score
def get_score_lines(df, conn, calc_date):
    #Get scoring columns using reference table in PHP96
    cols = list(df.columns)
    qry = '''
        SELECT DISTINCT metric
        FROM cd_stratum_metric
        WHERE ? BETWEEN start_date AND end_date
        '''
    metric_df = pd.read_sql_query(qry, conn, params = [calc_date])
    metric_values = set([x.strip(' ') for x in metric_df[metric_df.columns[0]]]) & set(cols)
    metric_flags = ["{}{}".format(i, '_missing_data') for i in metric_values]
    #Subset data, convert to long format
    id_cols = ['kcid', 'auth_no', 'program', 'age_group', 'calc_date']
    merge_cols = id_cols + ['metric']
    ##Get input values
    vals = pd.melt(df, id_vars = id_cols,
        value_vars = metric_values,
        var_name = 'metric')
    ##Get missing flags
    flags = pd.melt(df, id_vars = id_cols,
        value_vars = metric_flags,
        var_name = 'metric',
        value_name = 'missing_data')
    flags["metric"] = flags["metric"].str.replace("_missing_data", "")
    #Copy data into PHP96, run query, output result
    conn.execute("DROP TABLE IF EXISTS #phs_score")
    sql_in = vals.merge(flags, how = 'outer')
    sql_in.to_sql('#phs_score', con = conn, index = False)
    sql = qryhelper.get_query('phs_stratum_score.sql') #Read qry
    sql_out = pd.read_sql(sql, conn)
    return(sql_out)
