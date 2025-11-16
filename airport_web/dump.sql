-- MySQL dump 10.13  Distrib 5.7.27, for Linux (x86_64)
--
-- Host: localhost    Database: flights
-- ------------------------------------------------------
-- Server version	5.7.27-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `AIRLINE`
--

DROP TABLE IF EXISTS `AIRLINE`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AIRLINE` (
  `AIRLINEID` varchar(3) NOT NULL,
  `AL_NAME` varchar(50) DEFAULT NULL,
  `THREE_DIGIT_CODE` varchar(3) DEFAULT NULL,
  PRIMARY KEY (`AIRLINEID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `AIRLINE`
--

LOCK TABLES `AIRLINE` WRITE;
/*!40000 ALTER TABLE `AIRLINE` DISABLE KEYS */;
INSERT INTO `AIRLINE` VALUES ('9W','Jet Airways','589'),('AA','American Airlines','001'),('AI','Air India Limited','098'),('BA','British Airways','125'),('EK','Emirates','176'),('EY','Ethiad Airways','607'),('LH','Lufthansa','220'),('QR','Qatar Airways','157');
/*!40000 ALTER TABLE `AIRLINE` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `AIRPORT`
--

DROP TABLE IF EXISTS `AIRPORT`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `AIRPORT` (
  `AP_NAME` varchar(100) NOT NULL,
  `STATE` varchar(15) DEFAULT NULL,
  `COUNTRY` varchar(30) DEFAULT NULL,
  `CNAME` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`AP_NAME`),
  KEY `CNAME` (`CNAME`),
  CONSTRAINT `AIRPORT_ibfk_1` FOREIGN KEY (`CNAME`) REFERENCES `CITY` (`CNAME`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `AIRPORT`
--

LOCK TABLES `AIRPORT` WRITE;
/*!40000 ALTER TABLE `AIRPORT` DISABLE KEYS */;
INSERT INTO `AIRPORT` VALUES ('Chandigarh International Airport','Chandigarh','India','Chandigarh'),('Chhatrapati Shivaji International Airport','Maharashtra','India','Mumbai'),('Dallas/Fort Worth International Airport','Texas','United States','Fort Worth'),('Frankfurt Airport','Hesse','Germany','Frankfurt'),('George Bush Intercontinental Airport','Texas','United States','Houston'),('Indira GandhiInternational Airport','Delhi','India','Delhi'),('John F. Kennedy International Airport','New York','United States','New York City'),('San Francisco International Airport','California','United States','San Francisco'),('Tampa International Airport','Florida','United States','Tampa');
/*!40000 ALTER TABLE `AIRPORT` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CITY`
--

DROP TABLE IF EXISTS `CITY`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CITY` (
  `CNAME` varchar(15) NOT NULL,
  `STATE` varchar(15) DEFAULT NULL,
  `COUNTRY` varchar(30) DEFAULT NULL,
  PRIMARY KEY (`CNAME`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CITY`
--

LOCK TABLES `CITY` WRITE;
/*!40000 ALTER TABLE `CITY` DISABLE KEYS */;
INSERT INTO `CITY` VALUES ('Chandigarh','Chandigarh','India'),('Delhi','Delhi','India'),('Fort Worth','Texas','United States'),('Frankfurt','Hesse','Germany'),('Houston','Texas','United States'),('Louisville','Kentucky','United States'),('Mumbai','Maharashtra','India'),('New York City','New York','United States'),('San Francisco','California','United States'),('Tampa','Florida','United States');
/*!40000 ALTER TABLE `CITY` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `CONTAINS`
--

DROP TABLE IF EXISTS `CONTAINS`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `CONTAINS` (
  `AIRLINEID` varchar(3) NOT NULL,
  `AP_NAME` varchar(100) NOT NULL,
  PRIMARY KEY (`AIRLINEID`,`AP_NAME`),
  KEY `AP_NAME` (`AP_NAME`),
  CONSTRAINT `CONTAINS_ibfk_1` FOREIGN KEY (`AIRLINEID`) REFERENCES `AIRLINE` (`AIRLINEID`) ON DELETE CASCADE,
  CONSTRAINT `CONTAINS_ibfk_2` FOREIGN KEY (`AP_NAME`) REFERENCES `AIRPORT` (`AP_NAME`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `CONTAINS`
--

LOCK TABLES `CONTAINS` WRITE;
/*!40000 ALTER TABLE `CONTAINS` DISABLE KEYS */;
INSERT INTO `CONTAINS` VALUES ('AI','Chandigarh International Airport'),('BA','Chandigarh International Airport'),('AI','Chhatrapati Shivaji International Airport'),('BA','Chhatrapati Shivaji International Airport'),('LH','Chhatrapati Shivaji International Airport'),('QR','Chhatrapati Shivaji International Airport'),('AI','Dallas/Fort Worth International Airport'),('LH','Dallas/Fort Worth International Airport'),('QR','Dallas/Fort Worth International Airport'),('BA','Frankfurt Airport'),('LH','Frankfurt Airport'),('AA','George Bush Intercontinental Airport'),('AI','George Bush Intercontinental Airport'),('AI','Indira GandhiInternational Airport'),('AA','John F. Kennedy International Airport'),('BA','John F. Kennedy International Airport'),('LH','John F. Kennedy International Airport'),('QR','John F. Kennedy International Airport'),('AA','San Francisco International Airport'),('BA','San Francisco International Airport'),('LH','San Francisco International Airport'),('AA','Tampa International Airport'),('QR','Tampa International Airport');
/*!40000 ALTER TABLE `CONTAINS` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `EMPLOYEE1`
--

DROP TABLE IF EXISTS `EMPLOYEE1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EMPLOYEE1` (
  `SSN` int(11) NOT NULL,
  `FNAME` varchar(20) DEFAULT NULL,
  `M` varchar(1) DEFAULT NULL,
  `LNAME` varchar(20) DEFAULT NULL,
  `ADDRESS` varchar(100) DEFAULT NULL,
  `PHONE` int(11) DEFAULT NULL,
  `AGE` int(11) DEFAULT NULL,
  `SEX` varchar(1) DEFAULT NULL,
  `JOBTYPE` varchar(30) DEFAULT NULL,
  `PASSWORD` varchar(30) DEFAULT NULL,
  `ETYPE` varchar(30) DEFAULT NULL,
  `USERNAME` varchar(20) DEFAULT NULL,
  `POSITION` varchar(30) DEFAULT NULL,
  `AP_NAME` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`SSN`),
  KEY `AP_NAME` (`AP_NAME`),
  CONSTRAINT `EMPLOYEE1_ibfk_1` FOREIGN KEY (`AP_NAME`) REFERENCES `AIRPORT` (`AP_NAME`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `EMPLOYEE1`
--

LOCK TABLES `EMPLOYEE1` WRITE;
/*!40000 ALTER TABLE `EMPLOYEE1` DISABLE KEYS */;
INSERT INTO `EMPLOYEE1` VALUES (666884444,'SHELDON','A','COOPER','345 CHERRY PARK, HESSE,GERMANY',1254678903,55,'M','TRAFFIC MONITOR','cd17666830b55097a331e1e23175ba','NIGHT','scooper','','Frankfurt Airport');
/*!40000 ALTER TABLE `EMPLOYEE1` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `EMPLOYEE2`
--

DROP TABLE IF EXISTS `EMPLOYEE2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `EMPLOYEE2` (
  `JOBTYPE` varchar(30) NOT NULL,
  `SALARY` int(11) DEFAULT NULL,
  PRIMARY KEY (`JOBTYPE`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `EMPLOYEE2`
--

LOCK TABLES `EMPLOYEE2` WRITE;
/*!40000 ALTER TABLE `EMPLOYEE2` DISABLE KEYS */;
INSERT INTO `EMPLOYEE2` VALUES ('AIRPORT AUTHORITY',90000),('ENGINEER',70000),('TRAFFIC MONITOR',80000);
/*!40000 ALTER TABLE `EMPLOYEE2` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `FLIGHT`
--

DROP TABLE IF EXISTS `FLIGHT`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `FLIGHT` (
  `FLIGHT_CODE` varchar(10) NOT NULL,
  `SOURCE` varchar(3) DEFAULT NULL,
  `DESTINATION` varchar(3) DEFAULT NULL,
  `ARRIVAL` varchar(10) DEFAULT NULL,
  `DEPARTURE` varchar(10) DEFAULT NULL,
  `STATUS` varchar(10) DEFAULT NULL,
  `DURATION` varchar(30) DEFAULT NULL,
  `FLIGHTTYPE` varchar(10) DEFAULT NULL,
  `LAYOVER_TIME` varchar(30) DEFAULT NULL,
  `NO_OF_STOPS` int(11) DEFAULT NULL,
  `AIRLINEID` varchar(3) DEFAULT NULL,
  PRIMARY KEY (`FLIGHT_CODE`),
  KEY `AIRLINEID` (`AIRLINEID`),
  CONSTRAINT `FLIGHT_ibfk_1` FOREIGN KEY (`AIRLINEID`) REFERENCES `AIRLINE` (`AIRLINEID`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `FLIGHT`
--

LOCK TABLES `FLIGHT` WRITE;
/*!40000 ALTER TABLE `FLIGHT` DISABLE KEYS */;
INSERT INTO `FLIGHT` VALUES ('9W2334','IAH','DEL','23:00','13:45','On-time','23hrs','Direct','0',0,'9W'),('AA4367','SFO','FRA','18:10','18:55','On-time','21hrs','Non-stop','0',0,'AA'),('AI2014','BOM','DFW','02:10','03:15','On-time','24hr','Connecting','3',1,'AI'),('BA1689','FRA','DEL','10:20','10:55','On-time','14hrs','Non-stop','0',0,'BA'),('BA3056','BOM','DFW','02:15','02:55','On-time','29hrs','Connecting','3',1,'BA'),('EK3456','BOM','SFO','18:50','19:40','On-time','30hrs','Non-stop','0',0,'EK'),('EY1234','JFK','TPA','19:20','20:05','On-time','16hrs','Connecting','5',2,'EY'),('LH9876','JFK','BOM','05:50','06:35','On-time','18hrs','Non-stop','0',0,'LH'),('QR1902','IXC','IAH','22:00','22:50','Delayed','28hrs','Non-stop','5',1,'QR'),('QR2305','BOM','DFW','13:00','13:55','Delayed','21hr','Non-stop','0',0,'QR');
/*!40000 ALTER TABLE `FLIGHT` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `PASSENGER1`
--

DROP TABLE IF EXISTS `PASSENGER1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PASSENGER1` (
  `PID` int(11) NOT NULL,
  `PASSPORTNO` varchar(10) NOT NULL,
  PRIMARY KEY (`PID`,`PASSPORTNO`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `PASSENGER1`
--

LOCK TABLES `PASSENGER1` WRITE;
/*!40000 ALTER TABLE `PASSENGER1` DISABLE KEYS */;
INSERT INTO `PASSENGER1` VALUES (1,'A1234568'),(2,'B9876541'),(3,'C2345698'),(4,'D1002004'),(5,'X9324666'),(6,'B8765430'),(7,'J9801235'),(8,'A1122334'),(9,'Q1243567'),(10,'S1243269'),(11,'E3277889'),(12,'K3212322'),(13,'P3452390'),(14,'W7543336'),(15,'R8990566');
/*!40000 ALTER TABLE `PASSENGER1` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `PASSENGER2`
--

DROP TABLE IF EXISTS `PASSENGER2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PASSENGER2` (
  `PASSPORTNO` varchar(10) NOT NULL,
  `FNAME` varchar(20) DEFAULT NULL,
  `M` varchar(1) DEFAULT NULL,
  `LNAME` varchar(20) DEFAULT NULL,
  `ADDRESS` varchar(100) DEFAULT NULL,
  `PHONE` int(11) DEFAULT NULL,
  `AGE` int(11) DEFAULT NULL,
  `SEX` varchar(1) DEFAULT NULL,
  PRIMARY KEY (`PASSPORTNO`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `PASSENGER2`
--

LOCK TABLES `PASSENGER2` WRITE;
/*!40000 ALTER TABLE `PASSENGER2` DISABLE KEYS */;
/*!40000 ALTER TABLE `PASSENGER2` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `PASSENGER3`
--

DROP TABLE IF EXISTS `PASSENGER3`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `PASSENGER3` (
  `PID` int(11) NOT NULL,
  `FLIGHT_CODE` varchar(10) DEFAULT NULL,
  PRIMARY KEY (`PID`),
  KEY `FLIGHT_CODE` (`FLIGHT_CODE`),
  CONSTRAINT `PASSENGER3_ibfk_1` FOREIGN KEY (`FLIGHT_CODE`) REFERENCES `FLIGHT` (`FLIGHT_CODE`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `PASSENGER3`
--

LOCK TABLES `PASSENGER3` WRITE;
/*!40000 ALTER TABLE `PASSENGER3` DISABLE KEYS */;
INSERT INTO `PASSENGER3` VALUES (3,'9W2334'),(7,'9W2334'),(8,'AA4367'),(1,'AI2014'),(13,'AI2014'),(11,'BA1689'),(14,'BA1689'),(6,'BA3056'),(10,'EK3456'),(5,'EY1234'),(2,'LH9876'),(4,'QR1902'),(9,'QR1902'),(12,'QR1902'),(15,'QR2305');
/*!40000 ALTER TABLE `PASSENGER3` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `SERVES`
--

DROP TABLE IF EXISTS `SERVES`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `SERVES` (
  `SSN` int(11) NOT NULL,
  `PID` int(11) NOT NULL,
  `PASSPORTNO` varchar(10) NOT NULL,
  PRIMARY KEY (`SSN`,`PID`,`PASSPORTNO`),
  KEY `PID` (`PID`,`PASSPORTNO`),
  CONSTRAINT `SERVES_ibfk_1` FOREIGN KEY (`SSN`) REFERENCES `EMPLOYEE1` (`SSN`) ON DELETE CASCADE,
  CONSTRAINT `SERVES_ibfk_2` FOREIGN KEY (`PID`, `PASSPORTNO`) REFERENCES `PASSENGER1` (`PID`, `PASSPORTNO`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `SERVES`
--

LOCK TABLES `SERVES` WRITE;
/*!40000 ALTER TABLE `SERVES` DISABLE KEYS */;
/*!40000 ALTER TABLE `SERVES` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `TICKET1`
--

DROP TABLE IF EXISTS `TICKET1`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TICKET1` (
  `TICKET_NUMBER` int(11) NOT NULL,
  `SOURCE` varchar(3) DEFAULT NULL,
  `DESTINATION` varchar(3) DEFAULT NULL,
  `DATE_OF_BOOKING` date DEFAULT NULL,
  `DATE_OF_TRAVEL` date DEFAULT NULL,
  `SEATNO` varchar(5) DEFAULT NULL,
  `CLASS` varchar(15) DEFAULT NULL,
  `DATE_OF_CANCELLATION` date DEFAULT NULL,
  `PID` int(11) DEFAULT NULL,
  `PASSPORTNO` varchar(10) DEFAULT NULL,
  KEY `PID` (`PID`,`PASSPORTNO`),
  CONSTRAINT `TICKET1_ibfk_1` FOREIGN KEY (`PID`, `PASSPORTNO`) REFERENCES `PASSENGER1` (`PID`, `PASSPORTNO`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `TICKET1`
--

LOCK TABLES `TICKET1` WRITE;
/*!40000 ALTER TABLE `TICKET1` DISABLE KEYS */;
/*!40000 ALTER TABLE `TICKET1` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `TICKET2`
--

DROP TABLE IF EXISTS `TICKET2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TICKET2` (
  `DATE_OF_BOOKING` date NOT NULL,
  `SOURCE` varchar(3) NOT NULL,
  `DESTINATION` varchar(3) NOT NULL,
  `CLASS` varchar(15) NOT NULL,
  `PRICE` int(11) DEFAULT NULL,
  PRIMARY KEY (`DATE_OF_BOOKING`,`SOURCE`,`DESTINATION`,`CLASS`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `TICKET2`
--

LOCK TABLES `TICKET2` WRITE;
/*!40000 ALTER TABLE `TICKET2` DISABLE KEYS */;
/*!40000 ALTER TABLE `TICKET2` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `TICKET3`
--

DROP TABLE IF EXISTS `TICKET3`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `TICKET3` (
  `DATE_OF_CANCELLATION` date NOT NULL,
  `SURCHARGE` int(11) DEFAULT NULL,
  PRIMARY KEY (`DATE_OF_CANCELLATION`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `TICKET3`
--

LOCK TABLES `TICKET3` WRITE;
/*!40000 ALTER TABLE `TICKET3` DISABLE KEYS */;
/*!40000 ALTER TABLE `TICKET3` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2019-10-04  7:44:10