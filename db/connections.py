#Public packages
import os
import sys
from sqlalchemy import create_engine, event
import urllib

def php96_engine():
    #Make connection string
    string = urllib.parse.quote_plus("DRIVER={SQL Server Native client 11.0};"
                                    r"SERVER=KCITEC2SQEPRP;DATABASE=php96;"
                                    r"Trusted_connection=yes;MultiSubnetFailover=Yes;")

    #Connect to php96
    engine = create_engine("mssql+pyodbc:///?odbc_connect=%s" % string)
    return(engine)

def phclaims_engine():
    #Make connection string
    string = urllib.parse.quote_plus("DRIVER={SQL Server Native client 11.0};"
                                    r"SERVER=KCITSQLUTPDBH51;DATABASE=phclaims;"
                                    r"Trusted_connection=yes;MultiSubnetFailover=Yes;")
    #Connect to php96
    engine = create_engine("mssql+pyodbc:///?odbc_connect=%s" % string)
    return(engine)

def hhsaw_engine():
    #Make connection string
    string = urllib.parse.quote_plus("DRIVER={ODBC Driver 17 for SQL Server};"
                                    r"SERVER=kcitazrhpasqldev20.database.windows.net;"
                                    r"DATABASE=hhs_analytics_workspace;"
                                    r"Trusted_connection=yes;MultiSubnetFailover=Yes;")
    #Connect to php96
    engine = create_engine("mssql+pyodbc:///?odbc_connect=%s" % string)
    return(engine)
