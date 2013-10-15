# Carnivore SQS

Provides SQS `Carnivore::Source`

# Usage

```ruby
require 'carnivore'
require 'carnivore-sqs'

Carnivore.configure do
  source = Carnivore::Source.build(
    :type => {
      :fog => {...},
      :queues => ['arn:aws:sqs:...']
    }
  )
end.start!
```

# Info
* Carnivore: https://github.com/heavywater/carnivore
* Repository: https://github.com/heavywater/carnivore-sqs
* IRC: Freenode @ #heavywater
