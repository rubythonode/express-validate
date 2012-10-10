_ = require 'underscore'

_regexp = 
	ruleName: /%s/g
	ruleKey: /%([a-zA-Z]{1}([a-zA-Z0-9\-_]{1,})?)/g

Validator =
	rules: {}
	
	# given a name and a rule, add the rule to rules cache
	addRule: (name, rule) ->
		@rules[name] = rule
	
	# given the rule's name, return whether it's a valid rule 
	# (it has to have both test & message properties)
	checkRule: (name) ->
		rule = @rules[name]
		if typeof name == 'string' and rule and typeof rule.test == 'function' and typeof rule.message == 'string'
			return true
		
		throw new Error 'This is not a complete rule. A complete rule must contain both `test` function and `message` string.'
	
	# parses error messages
	# replaces %s with key name, %argName with rule.argName
	error: (rule, key, message, ruleArgs) ->
		unless message
			# no custom message passed
			message = @rules[rule].message
		return message.
			replace(_regexp.ruleName, key).
			replace(_regexp.ruleKey, (whole, first) =>
				if ruleArgs[first]
					return ruleArgs[first]
				else if @rules[rule][first]
					return @rules[rule][first]
				return whole
			)
	
	# perform the validation
	test: (obj, rule, key) ->
		theRule = rule
		
		unless typeof rule == 'string'
			theRule = rule.rule
		
		if @checkRule(theRule) 
			# allow rules using other rules by appling @rules to `test` method context
			context = _.extend @rules[theRule], rules: @rules
			
			if @rules[theRule].test.call context, obj[key], rule
				return @error theRule, key, rule.message, rule
		
		return false
	
	validate: (obj, ruleset) ->
		for key, rule of ruleset
			# check if it's an array of rules
			if Array.isArray rule
				for nestedRule in rule
					testResult = @test obj, nestedRule, key
					return testResult if testResult
			
			# single rule
			else
				testResult = @test obj, rule, key
				return testResult if testResult 
		
		return false

Validator.addRule 'required',
	message: "%s is requried."
	test: (str) ->
		return true unless str

Validator.addRule 'email',
	message: "%s must be a valid e-mail address."
	regex: ///^
	([\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+\.)*
	[\w\!\#$\%\&\'\*\+\-\/\=\?\^\`{\|\}\~]+
	@
	((((([a-z0-9]{1}[a-z0-9\-]{0,62}[a-z0-9]{1})|[a-z])\.)+[a-z]{2,6})|(\d{1,3}\.){3}\d{1,3}(\:\d{1,5})?)$
	///i
	test: (str) ->
		return false unless str
		return not @regex.test str

Validator.addRule 'minLength',
	message: "%s must be at least %minLength char long"
	minLength: 1
	test: (str, rule) ->
		return false unless str
		
		minLength = rule.minLength or @minLength
		
		return true if typeof str isnt 'string'
		return true if str.length < minLength

Validator.addRule 'greaterThan',
	message: "%s must be greater than %than"
	than: 1
	test: (str, rule) ->
		return false unless str
		
		than = rule.than or @than
		
		return true unless parseInt(str, 10) > than

Validator.addRule 'nonNegative',
	message: "%s must be non-negative"
	test: (str) ->
		return false unless str
		
		@rules.greaterThan.test str, than: -1

Validator.addRule 'match',
	message: "%s doesn't match the required pattern"
	pattern: //
	test: (str, rule) ->
		return false unless str
		
		pattern = rule.pattern or @pattern
		return true unless str.match pattern

module.exports = Validator