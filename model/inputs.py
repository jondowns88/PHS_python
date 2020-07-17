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
    key_vars2 = ['kcid', 'agency_id', 'auth_no', 'program', 'age_group',
        'LOCUS', 'LOCUS_missDat']
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
    conn.execute("DROP TABLE IF EXISTS #phs_locus_temp")
    return(out)

#Get LOCUS scores
def get_calocus(df, conn, calc_date):
    #Subset DF, make temp tab in SSMS
    key_vars = ['kcid', 'agency_id', 'auth_no', 'program', 'age_group']
    key_vars2 = ['kcid', 'agency_id', 'auth_no', 'program', 'age_group',
        'CALOC', 'CALOC_missDat']
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
    conn.execute("DROP TABLE IF EXISTS #phs_calocus_temp")
    return(out)

#Get foster status
def get_foster(df, conn, calc_date):
    #Subset DF, make temp tab in SSMS
    key_vars = ['kcid', 'auth_no']
    key_vars2 = ['kcid', 'auth_no', 'FOSTR']
    df_in = df[key_vars] #Subset input df
    df_in.to_sql('#phs_foster_temp', con = conn) #make temp table
    #Read in and parameterize query
    sql = get_query('phs_foster.sql') #Read qry
    sp = sqlparams.SQLParams('named', 'qmark') #Parameterize qry
    sql2, params = sp.format(sql, {'calc_date':calc_date})
    #Get result, join to main DF
    result = pd.read_sql(sql2, conn, params = params) #Get query result
    result2 = result[key_vars2] #Subset
    out = df.merge(result2, how = 'left') #Merge to input df
    out['FOSTR'] = out['FOSTR'].fillna(0) #Replace NA's with 0
    out['FOSTR_missDat'] = 'N' #Set missing flag to no (never missing)
    conn.execute("DROP TABLE IF EXISTS #phs_foster_temp")
    return(out)

#Get homeless status
def get_homeless(df, conn, calc_date):
    #Subset DF, make temp tab in SSMS
    key_vars = ['kcid', 'auth_no']
    key_vars2 = ['kcid', 'auth_no', 'HMLES']
    df_in = df[key_vars] #Subset input df
    df_in.to_sql('#phs_homeless_temp', con = conn) #make temp table
    #Read in and parameterize query
    sql = get_query('phs_homeless.sql') #Read qry
    sp = sqlparams.SQLParams('named', 'qmark') #Parameterize qry
    sql2, params = sp.format(sql, {'calc_date':calc_date})
    #Get result, join to main DF
    result = pd.read_sql(sql2, conn, params = params) #Get query result
    result2 = result[key_vars2] #Subset
    out = df.merge(result2, how = 'left') #Merge to input df
    out['HMLES'] = out['HMLES'].fillna(0) #Replace NA's with 0
    out['HMLES_missDat'] = 'N' #Set missing flag to no (never missing)
    conn.execute("DROP TABLE IF EXISTS #phs_homeless_temp")
    return(out)

#Get chronic conditions
def get_chronic_conditions(df, php96_conn, phclaims_conn, calc_date):
    #PHClaims query
    ph_sql = get_query('phs_chron_cond.sql') #Read qry
    ph_sp = sqlparams.SQLParams('named', 'qmark') #Parameterize qry
    ph_sql2, ph_params = ph_sp.format(ph_sql, {'calc_date':calc_date})
    ph_dat = pd.read_sql(ph_sql2, phclaims_conn, params = ph_params) #Get result
    #Subset data for PHP96 query
    df_in = df[['auth_no', 'p1_id']]
    df_in.to_sql('#phs_chron_cond_temp', con = php96_conn)
    #PHP96 query
    sql = get_query('phs_chron_cond_caa.sql') #Read qry
    sp = sqlparams.SQLParams('named', 'qmark') #Parameterize qry
    sql2, params = sp.format(sql, {'calc_date':calc_date})
    php96_dat = pd.read_sql(sql2, php96_conn)
    #Combine php96 and phclaims data into main DF. Replace NA's
    for_merge = php96_dat.merge(ph_dat, how = 'outer')
    na_fill = {'caa_asthma': 0, 'caa_diabetes': 0,
                'caa_copd': 0, 'caa_cvd': 0,
                'ccw_diabetes': 0, 'ccw_asthma': 0,
                'ccw_cvd': 0, 'ccw_copd': 0,
                'CHRON_missDat': 'Y'}
    out = df.merge(for_merge, how = 'left').fillna(na_fill)
    #We need to max 2 columns for each condition.
    #Define the columns.
    asthma_cols = ['caa_asthma', 'ccw_asthma']
    diabetes_cols = ['caa_diabetes', 'ccw_diabetes']
    copd_cols = ['caa_copd', 'ccw_copd']
    cvd_cols = ['caa_cvd', 'ccw_cvd']
    drop_cols = asthma_cols + diabetes_cols + copd_cols + cvd_cols
    #Take max
    out['asthma'] = out[asthma_cols].max(axis = 1)
    out['diabetes'] = out[diabetes_cols].max(axis = 1)
    out['copd'] = out[copd_cols].max(axis = 1)
    out['cvd'] = out[cvd_cols].max(axis = 1)
    #Sum total chronic conditions
    sum_cols = ['asthma', 'diabetes', 'copd', 'cvd']
    out['CHRON'] = out[sum_cols].sum(axis = 1)
    out_fin = out.drop(drop_cols, axis = 1)
    return(out_fin)

#Get chronic conditions
def get_high_util(df, conn, calc_date):
    conn.execute("DROP TABLE IF EXISTS jdowns.phs_hutil_temp")
    #Subset data, load to HHSAW
    df_in = df[['kcid']]
    df_in.to_sql('phs_hutil_temp', con = conn, schema = 'jdowns', index = False)
    #HHSAW query
    sql = get_query('phs_high_util.sql') #Read qry
    sp = sqlparams.SQLParams('named', 'qmark') #Parameterize qry
    sql2, params = sp.format(sql, {'calc_date':calc_date})
    sql_out = pd.read_sql(sql2, conn, params = params) #Get result
    na_fill = {'nSRS': 0, 'nDTX': 0, 'nITA': 0, 'nED': 0, 'nIP': 0, 'HUTIL': 0}
    out = df.merge(sql_out, how = 'left').fillna(na_fill)
    return(out)

#Get criminal justice events
def get_cj(df, conn, calc_date):
    sql = get_query('phs_cj.sql') #Read qry
    sp = sqlparams.SQLParams('named', 'qmark') #Parameterize qry
    sql2, params = sp.format(sql, {'calc_date':calc_date})
    na_fill = {'NUMCJ': 0, 'LNGCJ': 0}
    sql_out = pd.read_sql(sql2, conn, params = params) #Get result
    out = df.merge(sql_out, how = 'left').fillna(na_fill) #Merge to input df
    return(out)
