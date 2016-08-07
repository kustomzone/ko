# .................................................................................................................
level_dict["steps"] = {   
                        "scheme":   "blue_scheme",
                        "size":     (7,7,13),
                        "intro":    "steps",    
                        "help":     ( 
                                        "$scale(1.5)mission:\nget to the exit!\n\n" + \
                                        "to get to the exit,\njump on the stones",
                                        "to jump,\npress \"$key(jump)\"\nwhile moving",
                                        "to move, press \"$key(move forward)\" or \"$key(move backward)\",\n\n" + \
                                        "to turn, press \"$key(turn left)\" or \"$key(turn right)\"",
                                    ),
                        "player":   {   "coordinates":     (3,0,6),
                                        "nostatus":         0,
                                    },
                        "exits":    [
                                        {
                                            "name":         "exit",
                                            "active":       1,
                                            "position":     (0,1,3),
                                        },
                                    ],
                        "create":
"""
world.addObjectAtPos (KikiWall(), world.decenter (0,0,3))
world.addObjectAtPos (KikiWall(), world.decenter (0,-1,1))
world.addObjectAtPos (KikiWall(), world.decenter (0,-2,-1))
world.addObjectAtPos (KikiWall(), world.decenter (0,-3,-3))
""",                                 
}