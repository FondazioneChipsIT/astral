# Copyright 2026 Fondazione Chips-IT.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
#
# Author: Riccardo Fiorani Gallotta <riccardo.fiorani3@unibo.it>
# GLHF

import csv
import sys
import pandas
import numpy
import yaml
from pprint import pprint

if len(sys.argv) > 1:
    padframe_csv = sys.argv[1]
else:
    padframe_csv = 'padframe.csv'

if len(sys.argv) > 2:
    config_yml = sys.argv[2]
else:
    config_yml = 'config.yml'

if len(sys.argv) > 3:
    io_file = sys.argv[3]
else:
    io_file = 'output.io'

# Enable prints for debugging purposes
debug_print = False

if debug_print:
    print(f"\nPadframe csv file to be read: {padframe_csv}")
    print(f"Configuration yml file to be read: {config_yml}")
    print(f"IO file to be written: {io_file}\n")

###################################
# padframe csv file reading checks
###################################

# Read input CVS with the list of pads
csv = pandas.read_csv(padframe_csv)
if debug_print:
    print(f"File {padframe_csv} contains {len(csv.columns)} columns: {csv.columns.tolist()}\n")
    print(csv)

if len(csv.columns) != 3:
    print(f"\nThe padframe csv file {padframe_csv} has not the correct format")
    exit(1)

for i in range(len(csv.columns)):
    if csv.columns.tolist()[i] not in ['pad_nr', 'pad_name', 'type']:
        print(f"\nThe padframe csv file {padframe_csv} has not the correct format")
        exit(1)
    
if not isinstance(csv['pad_nr'][0], numpy.int64):
    print(f"\nThe padframe csv file {padframe_csv} has not the correct format")
    exit(1)

if not isinstance(csv['pad_name'][0], str):
    print(f"\nThe padframe csv file {padframe_csv} has not the correct format")
    exit(1)

if not isinstance(csv['type'][0], str):
    print(f"\nThe padframe csv file {padframe_csv} has not the correct format")
    exit(1)

##########################
# yml file reading checks
##########################

# Load config yml
with open(config_yml) as stream:
    try:
        config_data = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)
        exit(1)

if debug_print:
    print("Configuration yml file read:")
    pprint(config_data)

sides = ['BOTTOM', 'RIGHT', 'TOP', 'LEFT']
corners = ['BL', 'BR', 'TR', 'TL']
corner_names = {'BL': 'bottomleft', 'BR': 'bottomright', 'TR': 'topright', 'TL': 'topleft'}
rotations = [[['R0', 'R90', 'R180', 'R270'], ['MX', 'MX90', 'MY', 'MY90']], [['MY', 'MY90', 'MX', 'MX90'], ['R180', 'R270', 'R0', 'R90']]]

def get_rotation_indexes(val):
    index_2 = 0
    if val in rotations[index_2][0]:
        index_1 = 0
    elif val in rotations[index_2][1]:
        index_1 = 1
    else:
        return None
    index_0 = rotations[index_2][index_1].index(val)
    return index_2, index_1, index_0

def is_any_number(val):
    try:
        float(val)
        return True
    except (ValueError, TypeError):
        return False

def is_int_number(val):
    if isinstance(val, int):
        return True
    elif is_any_number(val) and isinstance(val, str):
        return val.isdigit()
    return False

def is_a_multiples_of(val, step):
    return abs(val/step - round(val/step)) < 0.00001

def is_multiplication_format(s):
    parts = s.split('*')
    if len(parts) != 2:
        return False
    try:
        val1 = int(parts[0])
        val2 = float(parts[1])
        return val1 >= 0 and val2 >= 0
    except ValueError:
        return False

def is_range_format(s):
    parts = s.split('-')
    if len(parts) != 2:
        return False
    try:
        val1 = int(parts[0])
        val2 = int(parts[1])
        return val1 >= 0 and val2 >= 0
    except ValueError:
        partss = parts[1].split(',')
        if len(partss) != 2:
            return False
    try:
        val2 = int(partss[0])
        val3 = int(partss[1])
        return val1 >= 0 and val2 >= 0 and val3 > 0
    except ValueError:
        return False

config_set = {}

if 'io_step' in config_data:
    if is_any_number(config_data['io_step']) and float(config_data['io_step']) > 0:
        config_set['io_step'] = float(config_data['io_step'])
    else:
        print(f"\n'io_step' has a wrong format in configuration yml file: {config_yml}")
        exit(1)
else:
    print(f"\n'io_step' not found in configuration yml file: {config_yml}")
    exit(1)

if 'io_dim' in config_data:
    config_set['io_dim'] = {}
    if is_any_number(config_data['io_dim']) and float(config_data['io_dim']) > 0:
        config_set['io_dim']['x'] = float(config_data['io_dim'])
        config_set['io_dim']['y'] = config_set['io_dim']['x']
    elif config_data['io_dim'] != None and 'x' in config_data['io_dim'] and 'y' in config_data['io_dim']:
        if is_any_number(config_data['io_dim']['x']) and float(config_data['io_dim']['x']) > 0:
            config_set['io_dim']['x'] = float(config_data['io_dim']['x'])
        else:
            print(f"\n'io_dim'.'x' has a wrong format in configuration yml file: {config_yml}")
            exit(1)
        if is_any_number(config_data['io_dim']['y']) and float(config_data['io_dim']['y']) > 0:
            config_set['io_dim']['y'] = float(config_data['io_dim']['y'])
        else:
            print(f"\n'io_dim'.'y' has a wrong format in configuration yml file: {config_yml}")
            exit(1)
    else:
        print(f"\n'io_dim' has a wrong format (need a number or both 'x' and 'y') in configuration yml file: {config_yml}")
        exit(1)
else:
    print(f"\n'io_dim' not found in configuration yml file: {config_yml}")
    exit(1)

if 'direction' in config_data:
    config_set['direction'] = {}
    if config_data['direction'] == "clockwise":
        config_set['direction']['TOP'] = False
        config_set['direction']['LEFT'] = False
        config_set['direction']['BOTTOM'] = False
        config_set['direction']['RIGHT'] = False
    elif config_data['direction'] == "counterclockwise":
        config_set['direction']['TOP'] = True
        config_set['direction']['LEFT'] = True
        config_set['direction']['BOTTOM'] = True
        config_set['direction']['RIGHT'] = True
    elif config_data['direction'] == "lrtb":
        config_set['direction']['TOP'] = False
        config_set['direction']['LEFT'] = True
        config_set['direction']['BOTTOM'] = True
        config_set['direction']['RIGHT'] = False
    elif config_data['direction'] == "rltb":
        config_set['direction']['TOP'] = True
        config_set['direction']['LEFT'] = True
        config_set['direction']['BOTTOM'] = False
        config_set['direction']['RIGHT'] = False
    elif config_data['direction'] == "lrbt":
        config_set['direction']['TOP'] = False
        config_set['direction']['LEFT'] = False
        config_set['direction']['BOTTOM'] = True
        config_set['direction']['RIGHT'] = True
    elif config_data['direction'] == "rlbt":
        config_set['direction']['TOP'] = True
        config_set['direction']['LEFT'] = False
        config_set['direction']['BOTTOM'] = False
        config_set['direction']['RIGHT'] = True
    else:
        print(f"\n'direction' has a wrong value in configuration yml file: {config_yml}")
        exit(1)
else:
    print(f"\n'direction' not found in configuration yml file: {config_yml}")
    exit(1)

if 'pad_types' in config_data:
    config_set['pad_types'] = {}
    if config_data['pad_types'] == None:
        print(f"\n'pad_types' is empty in configuration yml file: {config_yml}")
        exit(1)
    for pad_type in config_data['pad_types']:
        config_set['pad_types'][pad_type] = {}
        if config_data['pad_types'][pad_type] == None:
            print(f"\n'pad_types'.'{pad_type}' is empty in configuration yml file: {config_yml}")
            exit(1)
        #orientation
        if 'orientation' not in config_data['pad_types'][pad_type] or config_data['pad_types'][pad_type]['orientation'] not in ["vertical", "horizontal", "corner"]:
            print(f"\n'pad_types'.'{pad_type}'.'orientation' has a wrong value in configuration yml file: {config_yml}")
            exit(1)
        config_set['pad_types'][pad_type]['orientation'] = config_data['pad_types'][pad_type]['orientation']
        #rotation
        if 'rotation' not in config_data['pad_types'][pad_type] or config_data['pad_types'][pad_type]['rotation'] == None:
            config_set['pad_types'][pad_type]['rotation'] = get_rotation_indexes("R0")
        else:
            config_set['pad_types'][pad_type]['rotation'] = get_rotation_indexes(config_data['pad_types'][pad_type]['rotation'])
        if config_set['pad_types'][pad_type]['rotation'] == None:
            print(f"\n'pad_types'.'{pad_type}'.'rotation' has a wrong value in configuration yml file: {config_yml}")
            exit(1)
        #width
        if 'width' in config_data['pad_types'][pad_type] and is_any_number(config_data['pad_types'][pad_type]['width']) and float(config_data['pad_types'][pad_type]['width']) >= 0: 
            config_set['pad_types'][pad_type]['width'] = float(config_data['pad_types'][pad_type]['width'])
            if config_set['pad_types'][pad_type]['orientation'] != "corner" and (not is_a_multiples_of(config_set['pad_types'][pad_type]['width'], config_set['io_step'])):
                print(f"\n'pad_types'.'{pad_type}'.'width' is not a multiple of 'io_step' in configuration yml file: {config_yml}")
                exit(1)
        else:
            print(f"\n'pad_types'.'{pad_type}'.'width' has a wrong value in configuration yml file: {config_yml}")
            exit(1)
        #height
        if config_set['pad_types'][pad_type]['orientation'] == "corner":
            if 'height' not in config_data['pad_types'][pad_type] or config_data['pad_types'][pad_type]['height'] == None:
                config_set['pad_types'][pad_type]['height'] = config_set['pad_types'][pad_type]['width']
            else:
                if is_any_number(config_data['pad_types'][pad_type]['height']) and float(config_data['pad_types'][pad_type]['height']) >= 0:
                    config_set['pad_types'][pad_type]['height'] = float(config_data['pad_types'][pad_type]['height'])
                else:
                    print(f"\n'pad_types'.'{pad_type}'.'height' has a wrong value in configuration yml file: {config_yml}")
                    exit(1)
        #mirror
        if 'mirror' not in config_data['pad_types'][pad_type] or config_data['pad_types'][pad_type]['mirror'] == None:
            if config_set['pad_types'][pad_type]['orientation'] == "corner":
                config_set['pad_types'][pad_type]['mirror-x'] = False
                config_set['pad_types'][pad_type]['mirror-y'] = False
            else:
                config_set['pad_types'][pad_type]['mirror'] = False
        else:
            if config_data['pad_types'][pad_type]['mirror'] not in [True, False]:
                print(f"\n'pad_types'.'{pad_type}'.'mirror' has a wrong value in configuration yml file: {config_yml}")
                exit(1)
            if config_set['pad_types'][pad_type]['orientation'] == "corner":
                if 'mirror-x' not in config_data['pad_types'][pad_type]:
                    config_set['pad_types'][pad_type]['mirror-x'] = config_data['pad_types'][pad_type]['mirror']
                elif config_data['pad_types'][pad_type]['mirror-x'] not in [True, False]:
                    print(f"\n'pad_types'.'{pad_type}'.'mirror-x' has a wrong value in configuration yml file: {config_yml}")
                    exit(1)
                else:
                    config_set['pad_types'][pad_type]['mirror-x'] = config_data['pad_types'][pad_type]['mirror-x']
                if 'mirror-y' not in config_data['pad_types'][pad_type]:
                    config_set['pad_types'][pad_type]['mirror-y'] = config_data['pad_types'][pad_type]['mirror']
                elif config_data['pad_types'][pad_type]['mirror-y'] not in [True, False]:
                    print(f"\n'pad_types'.'{pad_type}'.'mirror-y' has a wrong value in configuration yml file: {config_yml}")
                    exit(1)
                else:
                    config_set['pad_types'][pad_type]['mirror-y'] = config_data['pad_types'][pad_type]['mirror-y']
            else:
                config_set['pad_types'][pad_type]['mirror'] = config_data['pad_types'][pad_type]['mirror']
        #rtl_name
        if 'rtl_name' not in config_data['pad_types'][pad_type]:
            print(f"\n'pad_types'.'{pad_type}'.'rtl_name' has a wrong value in configuration yml file: {config_yml}")
            exit(1)
        if not isinstance(config_data['pad_types'][pad_type]['rtl_name'], str):
            print(f"\n'pad_types'.'{pad_type}'.'rtl_name' has a wrong value in configuration yml file: {config_yml}")
            exit(1)
        config_set['pad_types'][pad_type]['rtl_name'] = config_data['pad_types'][pad_type]['rtl_name'].replace("*", "{pad_name}")
else:
    print(f"\n'pad_types' not found in configuration yml file: {config_yml}")
    exit(1)

for side in sides:
    config_set[side] = {
        'step': None,
        'margin': 0.0,
        'start_offset': [],
        'end_offset': [],
        'pad_numbers': []
    }
    if side in config_data and config_data[side] != None:
        #step
        if 'step' in config_data[side] and config_data[side]['step'] != None:
            if not is_any_number(config_data[side]['step']) or float(config_data[side]['step']) < 0:
                print(f"\n'{side}'.'step' has a wrong value in configuration yml file: {config_yml}")
                exit(1)
            config_set[side]['step'] = float(config_data[side]['step'])
        #margin
        if 'margin' in config_data[side] and config_data[side]['margin'] != None:
            if not is_any_number(config_data[side]['margin']) or float(config_data[side]['margin']) < 0:
                print(f"\n'{side}'.'margin' has a wrong value in configuration yml file: {config_yml}")
                exit(1)
            config_set[side]['margin'] = float(config_data[side]['margin'])
        #start_offset
        if 'start_offset' in config_data[side]:
            if not isinstance(config_data[side]['start_offset'], list):
                print(f"\n'{side}'.'start_offset' has a wrong value in configuration yml file: {config_yml}")
                exit(1)
            for offset in config_data[side]['start_offset']:
                if is_any_number(offset) and float(offset) >= 0:
                    config_set[side]['start_offset'].append(float(offset))
                elif isinstance(offset, str) and is_multiplication_format(offset):
                    config_set[side]['start_offset'].extend([float(offset.split('*')[1]) for i in range(int(offset.split('*')[0]))])
                else:
                    print(f"\n'{side}'.'start_offset' has a wrong value in configuration yml file: {config_yml}")
                    exit(1)
        #end_offset
        if 'end_offset' in config_data[side]:
            if not isinstance(config_data[side]['end_offset'], list):
                print(f"\n'{side}'.'end_offset' has a wrong value in configuration yml file: {config_yml}")
                exit(1)
            for offset in config_data[side]['end_offset']:
                if is_any_number(offset) and float(offset) >= 0:
                    config_set[side]['end_offset'].append(float(offset))
                elif isinstance(offset, str) and is_multiplication_format(offset):
                    config_set[side]['end_offset'].extend([float(offset.split('*')[1]) for i in range(int(offset.split('*')[0]))])
                else:
                    print(f"\n'{side}'.'end_offset' has a wrong value in configuration yml file: {config_yml}")
                    exit(1)
        #pad_numbers
        if 'pad_numbers' in config_data[side] and config_data[side]['pad_numbers'] != None:
            if not isinstance(config_data[side]['pad_numbers'], list):
                print(f"\n'{side}'.'pad_numbers' has a wrong value in configuration yml file: {config_yml}")
                exit(1)
            for pad_number in config_data[side]['pad_numbers']:
                if is_int_number(pad_number) and int(pad_number) >= 0:
                    config_set[side]['pad_numbers'].append(int(pad_number))
                elif isinstance(pad_number, str) and is_range_format(pad_number):
                    val1 = int(pad_number.split('-')[0])
                    if len(pad_number.split(',')) != 2:
                        val2 = int(pad_number.split('-')[1])
                        val3 = 1
                    else:
                        val2 = int(pad_number.split('-')[1].split(',')[0])
                        val3 = int(pad_number.split('-')[1].split(',')[1])
                    val3 = (-val3 if val1 > val2 else val3)
                    config_set[side]['pad_numbers'].extend(list(range(val1,val2,val3)))
                else:
                    print(f"\n'{side}'.'pad_numbers' has a wrong format in configuration yml file: {config_yml}")
                    exit(1)

config_set['CORNERS'] = {}
for corner in corners:
    config_set['CORNERS'][corner] = {
        'pad_number': None
    }
if 'CORNERS' in config_data and config_data['CORNERS'] != None:
    for corner in corners:
        if corner in config_data['CORNERS'] and config_data['CORNERS'][corner] != None:
            if is_int_number(config_data['CORNERS'][corner]) and int(config_data['CORNERS'][corner]) >= 0:
                config_set['CORNERS'][corner]['pad_number'] = int(config_data['CORNERS'][corner])
            else:
                print(f"\n'CORNERS'.'{corner}'.'pad_number' has a wrong format in configuration yml file: {config_yml}")
                exit(1)

if debug_print:
    print("\nConfiguration loaded:")
    pprint(config_set)

#########################
# calculating positions
#########################

pad_positions = {}
already_used_pads = []
sides_width = {
    'TOP': config_set['io_dim']['x'],
    'LEFT': config_set['io_dim']['y'],
    'BOTTOM': config_set['io_dim']['x'],
    'RIGHT': config_set['io_dim']['y']
}

def do_rotate(distance, mirror_x, mirror_y):
    if distance == 1:
        if mirror_y:
            rotate = [ 1, 0, 0 ]
        else:
            rotate = [ 0, 0, 1 ]
    elif distance == 2:
        if (mirror_x and mirror_y):
            rotate = [ 1, 1, 0 ]
        elif mirror_y:
            rotate = [ 1, 0, 1 ]
        elif mirror_x:
            rotate = [ 0, 1, -1 ]
        else:
            rotate = [ 0, 0, 2 ]
    elif distance == 3:
        if mirror_x:
            rotate = [ 0, 1, 0 ]
        else:
            rotate = [ 0, 0, -1 ]
    else:
        rotate = [ 0, 0, 0 ]
    return rotate

def do_flip(orientation, mirror):
    if mirror:
        if orientation == "vertical":
            rotate = [ 0, 1, 0 ]
        else:
            rotate = [ 1, 0, 0 ]
    else:
        rotate = [ 0, 0, 2 ]
    return rotate

def snap_to_step(distance, step):
    return round(distance/step)*step

for side in sides:
    pad_positions[side] = {}
    pad_positions[side]['offset'] = {}
    pad_positions[side]['margin'] = config_set[side]['margin']
    pad_positions[side]['step'] = config_set[side]['step']
    pad_positions[side]['reverse'] = not config_set['direction'][side]

for corner in corners:
    corner_pad = config_set['CORNERS'][corner]
    if corner_pad['pad_number'] != None:
        if corner_pad['pad_number'] in already_used_pads:
            print(f"\nCorner {corner}: pad nr {corner_pad['pad_number']} already used")
            exit(1)
        already_used_pads.append(corner_pad['pad_number'])
        if len(csv[csv['pad_nr']==corner_pad['pad_number']]) != 1:
            print(f"\nDuplicated entries for pad nr {corner_pad['pad_number']} in csv file: {padframe_csv}")
            exit(1)
        if csv.loc[csv['pad_nr']==corner_pad['pad_number'], 'type'].item() not in config_set['pad_types']:
            print(f"\nPad nr {corner_pad['pad_number']} type not defined in configuration yml file: {config_yml}")
            exit(1)
        pad_type = config_set['pad_types'][csv.loc[csv['pad_nr']==corner_pad['pad_number'], 'type'].item()]
        if pad_type['orientation'] != "corner":
            print(f"\nPad orientation for pad nr {corner_pad['pad_number']} type is not corner")
            exit(1)
        pad_positions[corner] = {}
        pad_positions[corner]['offset_side'] = {}
        pad_positions[corner]['offset_side']['x'] = pad_type['width' if corners.index(corner) % 2 == 0 else 'height']
        pad_positions[corner]['offset_side']['y'] = pad_type['width' if corners.index(corner) % 2 == 1 else 'height']
        pad_positions[corner]['instance_name'] = pad_type['rtl_name'].format(pad_name=csv.loc[csv['pad_nr']==corner_pad['pad_number'], 'pad_name'].item())
        rotate = do_rotate(corners.index(corner), pad_type['mirror-x'], pad_type['mirror-y'])
        pad_positions[corner]['rotation'] = rotations[pad_type['rotation'][0]+rotate[0]][pad_type['rotation'][1]+rotate[1]][pad_type['rotation'][2]+rotate[2]]
    else:
        pad_positions[corner] = {}
        pad_positions[corner]['offset_side'] = {'x': 0.0, 'y': 0.0}
        pad_positions[corner]['instance_name'] = None
        pad_positions[corner]['rotation'] = None
    sides_width[sides[corners.index(corner)]] = sides_width[sides[corners.index(corner)]] \
                                                - pad_positions[corner]['offset_side']['x' if corners.index(corner) % 2 == 0 else 'y'] \
                                                - pad_positions[sides[(corners.index(corner)+1)%4]]['margin'] \
                                                - pad_positions[sides[(corners.index(corner)-1)%4]]['margin']
    sides_width[sides[(corners.index(corner)-1)%4]] = sides_width[sides[(corners.index(corner)-1)%4]] - pad_positions[corner]['offset_side']['x' if corners.index(corner) % 2 == 1 else 'y']
    pad_positions[sides[corners.index(corner)]]['offset']['l'] = pad_positions[corner]['offset_side']['x' if corners.index(corner) % 2 == 0 else 'y']
    pad_positions[sides[(corners.index(corner)-1)%4]]['offset']['r'] = pad_positions[corner]['offset_side']['x' if corners.index(corner) % 2 == 1 else 'y']

if debug_print:
    print("\nSide width calculated:")
    pprint(sides_width)

for side in sides:
    if not is_a_multiples_of(sides_width[side], config_set['io_step']):
        print(f"\nSide '{side}' width (total - varius offset = {sides_width[side]}) is not a multiple of 'io_step' in configuration yml file: {config_yml}")
        exit(1)
    pad_positions[side]['pads']=[]
    pad_need_offset = []
    left = 0.
    right = sides_width[side]
    for pad_number in config_set[side]['pad_numbers']:
        if pad_number in already_used_pads:
            print(f"\nSide {side}: pad nr {pad_number} already used")
            exit(1)
        already_used_pads.append(pad_number)
        if len(csv[csv['pad_nr']==pad_number]) != 1:
            print(f"\nDuplicated entries for pad nr {pad_number} in csv file: {padframe_csv}")
            exit(1)
        if csv.loc[csv['pad_nr']==pad_number, 'type'].item() not in config_set['pad_types']:
            print(f"\nPad nr {pad_number} type not defined in configuration yml file: {config_yml}")
            exit(1)
        pad_type = config_set['pad_types'][csv.loc[csv['pad_nr']==pad_number, 'type'].item()]
        if pad_type['orientation'] != ('vertical' if sides.index(side) % 2 == 0 else 'horizontal'):
            print(f"\nPad orientation for pad nr {pad_number} type is not right for side {side}")
            exit(1)
        pad_index = config_set[side]['pad_numbers'].index(pad_number)
        pad_positions[side]['pads'].append({})
        if pad_index < len(config_set[side]['start_offset']):
            left += snap_to_step(config_set[side]['start_offset'][pad_index], config_set['io_step'])
            pad_positions[side]['pads'][pad_index]['offset'] = left
        elif (len(config_set[side]['pad_numbers']) - pad_index - 1) < len(config_set[side]['end_offset']):
            right -= snap_to_step(config_set[side]['end_offset'][len(config_set[side]['pad_numbers']) - pad_index - 1], config_set['io_step'])
            pad_positions[side]['pads'][pad_index]['offset'] = right
        elif config_set[side]['step'] != None:
            left += snap_to_step(config_set[side]['step'], config_set['io_step'])
            pad_positions[side]['pads'][pad_index]['offset'] = left
        else:
            pad_need_offset.append(pad_number)
        pad_positions[side]['pads'][pad_index]['instance_name'] = pad_type['rtl_name'].format(pad_name=csv.loc[csv['pad_nr']==pad_number, 'pad_name'].item())
        rotate = [0,0,0]
        if sides.index(side) == 1 or sides.index(side) == 2:
            rotate = do_flip(pad_type['orientation'], pad_type['mirror'])
        pad_positions[side]['pads'][pad_index]['rotation'] = rotations[pad_type['rotation'][0]+rotate[0]][pad_type['rotation'][1]+rotate[1]][pad_type['rotation'][2]+rotate[2]]
    if left > right:
        print(f"\nSide {side} went out of bounds")
        exit(1)
    if len(pad_need_offset) > 0:
        pads_width = 0.
        for pad_number in pad_need_offset:
            pads_width += config_set['pad_types'][csv.loc[csv['pad_nr']==pad_number, 'type'].item()]['width']
        if config_set[side]['pad_numbers'].index(pad_need_offset[0]) != 0:
            pad_index = config_set[side]['pad_numbers'].index(pad_need_offset[0])-1 
            pads_width += config_set['pad_types'][csv.loc[csv['pad_nr']==config_set[side]['pad_numbers'][pad_index], 'type'].item()]['width']
        step = (right - left - pads_width) / (len(pad_need_offset) + 1)
        i = 1
        for pad_number in pad_need_offset:
            pad_index = config_set[side]['pad_numbers'].index(pad_number)
            pad_positions[side]['pads'][pad_index]['offset'] = snap_to_step(left + i * step, config_set['io_step'])
            left += config_set['pad_types'][csv.loc[csv['pad_nr']==pad_number, 'type'].item()]['width']
            i += 1
    for pad in pad_positions[side]['pads']:
        if pad_positions[side]['reverse']:
            pad_index = pad_positions[side]['pads'].index(pad)
            pad['offset'] = sides_width[side] - pad['offset'] + pad_positions[side]['offset']['l'] - config_set['pad_types'][csv.loc[csv['pad_nr']==config_set[side]['pad_numbers'][pad_index], 'type'].item()]['width']
        else:
            pad['offset'] += pad_positions[side]['offset']['l']
    if pad_positions[side]['reverse']:
        pad_positions[side]['pads'].reverse()


if debug_print:
    print("\nPad positions calculated:")
    pprint(pad_positions)

single_tab = "\t"
double_tab = single_tab * 2
triple_tab = single_tab * 3

# Add the fixed template to the Innovus IO file
with open(io_file, 'w') as io_file:
    io_file.write('# Copyright 2026 Fondazione Chips-IT.\n')
    io_file.write('# Licensed under the Apache License, Version 2.0, see LICENSE for details.\n')
    io_file.write('# SPDX-License-Identifier: Apache-2.0\n\n')
    io_file.write(f'# Generated IO file {io_file.name} from {padframe_csv} and {config_yml}.\n')
    io_file.write('# This file is automatically generated.\n')
    io_file.write('\n')
    io_file.write('( globals\n')
    io_file.write(single_tab+'version = 3\n')
    io_file.write(single_tab+'io_order = counterclockwise\n')
    io_file.write(')\n')
    io_file.write('\n')
    io_file.write('( row_margin\n')
    for side in sides:
        io_file.write(single_tab+f'( {side.lower()}\n')
        io_file.write(double_tab+'( io_row ring_number = 1 margin = '+str(pad_positions[side]['margin'])+' )\n')
        io_file.write(single_tab+')\n')
    io_file.write(')\n')
    io_file.write('\n')
    io_file.write('( iopad\n')
    for corner in corners:
        if pad_positions[corner]['instance_name'] != None:
            io_file.write(single_tab+f'( {corner_names[corner]}\n')
            io_file.write(double_tab+'( locals ring_number = 1 )\n')
            io_file.write(double_tab+'( inst name = "'+pad_positions[corner]['instance_name']+'" orientation = '+pad_positions[corner]['rotation']+' )\n')
            io_file.write(single_tab+')\n')
    for side in sides:
        if len(pad_positions[side]['pads']) > 0:
            io_file.write(single_tab+f'( {side.lower()}\n')
            io_file.write(double_tab+'( locals ring_number = 1 )\n')
            for pad in pad_positions[side]['pads']:
                io_file.write(double_tab+'( inst name = "'+pad['instance_name']+'" orientation = '+pad['rotation']+' offset = '+str(pad['offset'])+' )\n')
            io_file.write(single_tab+')\n')
    io_file.write(')\n')

print(f"Generated {io_file.name}.")
