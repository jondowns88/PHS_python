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
