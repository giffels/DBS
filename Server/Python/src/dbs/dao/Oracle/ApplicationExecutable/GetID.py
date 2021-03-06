#!/usr/bin/env python
"""
This module provides ApplicationExecutable.GetID data access object.
"""
from WMCore.Database.DBFormatter import DBFormatter
from dbs.utils.dbsExceptionHandler import dbsExceptionHandler

class GetID(DBFormatter):
    """
    File GetID DAO class.
    """
    def __init__(self, logger, dbi, owner):
        """
        Add schema owner and sql.
        """
        DBFormatter.__init__(self, logger, dbi)
        self.owner = "%s." % owner if not owner in ("", "__MYSQL__") else ""
        self.sql = \
	"""
	SELECT A.APP_EXEC_ID
	FROM %sAPPLICATION_EXECUTABLES A WHERE A.APP_NAME = :app_name
	""" % ( self.owner )
        
    def execute(self, conn, name,transaction = False):
        """
        returns id for a given application
        """
        if not conn:
	    dbsExceptionHandler("dbsException-db-conn-failed","Oracle/ApplicationExecutable/GetID. Expects db connection from upper layer.")
            
        binds = {"app_name":name}
        result = self.dbi.processData(self.sql, binds, conn, transaction)
        plist = self.formatDict(result)
        #print "Searching for appID for %s" %binds
        #print "Went to look for appID: %s" %plist
        if len(plist) < 1 : return -1
        return plist[0]["app_exec_id"]

