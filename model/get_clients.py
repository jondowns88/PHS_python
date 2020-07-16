#Import other libraries
import pandas as pd
import numpy as np
import os
import pyodbc
import math
import datetime
from dateutil.relativedelta import relativedelta
import calendar
import sqlparams

#Function to automate the reading of queries.
def get_query(qry_string):
    qry_path = os.path.join(os.getcwd(), 'sql', qry_string)
    qry_file = open(qry_path)
    sql = qry_file.read()
    qry_file.close()
    return(sql)

#Find the minimum of the day jail data were updated and the calc date
def get_jail_date(calc_date):
    qry = "SELECT MAX(booking_start) FROM muni_jail"
    date = pd.read_sql_query(qry, conn).iloc[0].to_string().strip()
    date2 = datetime.datetime.strptime(date, "%Y-%m-%d").date()
    date_list = [date2, calc_date]
    return(min(date_list))

#Get clients in need of stratification
def get_clients(conn, start_date, end_date):
    sql = get_query('phs_strat_population.sql')
    out = pd.read_sql_query(sql, conn, params = [start_date, end_date])
    return(out)

#Get LOCUS scores
def get_locus(df, conn, calc_date):
    #Subset DF, make temp tab in SSMS
    key_vars = ['kcid', 'agency_id', 'auth_no', 'program', 'age_group']
    key_vars2 = ['kcid', 'agency_id', 'auth_no', 'program', 'age_group', 'LOCUS', 'LOCUS_missDat']
    df_in = df[key_vars] #Subset input df
    df_in.to_sql('#phs_locus_temp', con = conn) #make temp table
    #Read in and parameterize query
    sql = get_query('phs_locus.sql') #Read qry
    sp = sqlparams.SQLParams('named', 'qmark') #Parameterize qry
    sql2, params = sp.format(sql, {'calc_date':calc_date})
    #Get result, join to main DF
    result = pd.read_sql(sql2, conn, params = params) #Get query result
    result2 = result[key_vars2] #Subset
    out = df.merge(result2, how = 'left') #Merge to input df
    out['LOCUS'] = out['LOCUS'].fillna(0) #Replace NA's with 0
    return(out)

#Get LOCUS scores
def get_calocus(df, conn, calc_date):
    #Subset DF, make temp tab in SSMS
    key_vars = ['kcid', 'agency_id', 'auth_no', 'program', 'age_group']
    key_vars2 = ['kcid', 'agency_id', 'auth_no', 'program', 'age_group', 'CALOC', 'CALOC_missDat']
    df_in = df[key_vars] #Subset input df
    df_in.to_sql('#phs_calocus_temp', con = conn) #make temp table
    #Read in and parameterize query
    sql = get_query('phs_calocus.sql') #Read qry
    sp = sqlparams.SQLParams('named', 'qmark') #Parameterize qry
    sql2, params = sp.format(sql, {'calc_date':calc_date})
    #Get result, join to main DF
    result = pd.read_sql(sql2, conn, params = params) #Get query result
    result2 = result[key_vars2] #Subset
    out = df.merge(result2, how = 'left') #Merge to input df
    out['CALOC'] = out['CALOC'].fillna(0) #Replace NA's with 0
    return(out)
