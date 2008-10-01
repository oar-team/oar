CONFIG+=qt debug console
QT-= gui
QT+= sql

SOURCES+=Oar_iolib.cc
SOURCES+=Gantt_hole_storage.cc
SOURCES+=Oar_resource_tree.cc
SOURCES+=Oar_sched_gantt_with_timesharing_and_fairsharing.cc


HEADERS+=Gantt_hole_storage.H
HEADERS+=Oar_resource_tree.H

TARGET=Oar_sched_gantt_with_timesharing_and_fairsharing


