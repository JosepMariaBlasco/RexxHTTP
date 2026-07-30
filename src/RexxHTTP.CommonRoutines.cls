/******************************************************************************/
/*                                                                            */
/* RexxHTTP.CommonRoutines.cls - Shared helper routines for rexxlets          */
/* =================================================================          */
/*                                                                            */
/* This file is part of the RexxHTTP package                                  */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2006-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* A home for routines that many rexxlets need but that do not belong to any  */
/* single request/response object. A rexxlet loads it by absolute path,       */
/* anchored at the installation root, which Apache hands us as the            */
/* REXXHTTP_BASE environment variable (frozen at install time):               */
/*                                                                            */
/*     .context~package~loadPackage( -                                        */
/*        .request~RexxHTTP_base"/src/RexxHTTP.CommonRoutines.cls" )          */
/*                                                                            */
/* REXXHTTP_BASE carries no trailing separator; the caller supplies the "/".  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260705    1.0  First version                                             */
/*                                                                            */
/******************************************************************************/

